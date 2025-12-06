// This is not complete.
// - It can't check unnamed struct/union declarations (e.g. in `union { foo: int; bar: float; }`)
// - It can't check if using declarations are actually used. (e.g. `using a: struct { foo: int; bar: float; }`).
//   I should probably not check the using declarations at all so the output is less polluted.
// - It can't check if variables are used inside #asm blocks.
// - Some edge cases might not be handled. Dunno.


Check_Unused_Variables_Plugin :: struct {
    #as using plugin: Metaprogram_Plugin;
    excluded_paths: [..]string;
    unused_variables_count: s64;
    include_constants: bool;
}

// Yes, I am lazy...
#add_context check_unused_variables_plugin: *Check_Unused_Variables_Plugin;

get_plugin :: () -> *Metaprogram_Plugin {
    p := New(Check_Unused_Variables_Plugin);

    p.before_intercept  = null;
    p.add_source        = null;
    p.message           = message;
    p.finish            = finish;
    p.shutdown          = shutdown;
    p.init              = init;
    p.log_help          = log_help;

    return p;
}

init :: (p: *Metaprogram_Plugin, args: []string) -> bool {
    plugin := cast(*Check_Unused_Variables_Plugin) p;
    context.check_unused_variables_plugin = plugin;
    check_jai_modules: bool;

    index := 0;
    while index < args.count {
        defer index += 1;
        arg := args[index];
        if arg == {
        case "-include_constants";
            plugin.include_constants = true;
        case "-check_jai_modules";
            check_jai_modules = true;
        case "-exclude_module_path";
            if index >= args.count-1 {
                log_error("Missing argument to \"%\".\n", arg);
                return false;
            }
            index += 1;

            array_add(*plugin.excluded_paths, args[index]);
        case;
            log_error("Unknown argument \"%\".", arg);
            return false;
        }
    }

    if !check_jai_modules {
        base_modules := join(compiler_get_base_path(), "/modules"); // @Leak;
        array_add(*plugin.excluded_paths, base_modules);
    }

    return true;
}

shutdown :: (p: *Metaprogram_Plugin) {
    plugin := cast(*Check_Unused_Variables_Plugin) p;
    if plugin.excluded_paths  array_free(plugin.excluded_paths);
    context.check_unused_variables_plugin = null;
}

message :: (p: *Metaprogram_Plugin, message: *Message) {
    plugin := cast(*Check_Unused_Variables_Plugin) p;

    if message.kind == {
    case .TYPECHECKED;
        code := cast(*Message_Typechecked) message;
        for code.procedure_bodies {
            header := it.expression.header;

            exclude: bool;
            enclosing_import := header.enclosing_load.enclosing_import;
            if enclosing_import != null {
                for plugin.excluded_paths {
                    if begins_with(enclosing_import.fully_pathed_filename, it) {
                        exclude = true;
                        break;
                    }
                }
            }

            if !exclude {
                check_procedure(header);
            }
        }
    }
}

finish :: (p: *Metaprogram_Plugin) {
    plugin := cast(*Check_Unused_Variables_Plugin) p;

    log("===============================");
    log("Total unused variables: %.", plugin.unused_variables_count);
    log("===============================");
}

log_help :: (p: *Metaprogram_Plugin) {
    log(HELP_STRING);
}


#scope_file
#import "Metaprogram_Plugins";
#import "Compiler";
#import "Basic";
#import "String";

HELP_STRING :: #string DONE
    Available arguments:
        -check_jai_modules                 - check the modules shipped with the compiler as well.
        -exclude_module_path /path/        - exclude modules containing the given path.
DONE;


Declaration :: struct {
    decl: *Code_Declaration;
    use_count: s32;
}

check_procedure :: (header: *Code_Procedure_Header) {
    declarations: [..]Declaration;
    defer array_free(declarations);

    /* for header.constants_block.members {
        assert(it.kind == .DECLARATION);
        decl := cast(*Code_Declaration) it;
        assert(xx (decl.flags & .IS_CONSTANT));
        array_add(*declarations, .{decl=decl});
    } */

    for header.arguments {
        array_add(*declarations, .{decl=it});
    }

    check_block(header.body_or_null.block, *declarations);
}

check_block :: (block: *Code_Block, decls: *[..]Declaration) {
    assert(block != null);
    assert(block.belongs_to_struct == null);
    decls_stack_mark := decls.count;
    defer decls.count = decls_stack_mark;

    for block.members {
        assert(it.kind == .DECLARATION);
        decl := cast(*Code_Declaration) it;

        if decl.node_flags & .CREATED_BY_DESUGARING  continue;
        if decl.flags & .IS_IMPORTED     continue;
        if decl.flags & .COMES_FROM_ASM  continue;
        if decl.flags & .IS_CONSTANT && !context.check_unused_variables_plugin.include_constants  continue;

        // @Incomplete: Also remove declarations that are marked as using ?

        // If the declaration is backticked, we skip it.
        if decl.flags & .HAS_SCOPE_MODIFIER  continue;

        array_add(decls, .{decl=decl});
    }

    for block.statements {
        check_expression(it, decls);
    }

    count_unused_declarations(decls.*, decls_stack_mark);
}

check_expression :: (expr: *Code_Node, decls: *[..]Declaration) {
    assert(expr != null);
    if expr.kind == {
    case .BLOCK;
        check_block(cast(*Code_Block) expr, decls);

    case .PUSH_CONTEXT;
        code_push_context:= cast(*Code_Push_Context) expr;
        check_expression(code_push_context.to_push, decls);
        if code_push_context.block != null  check_block(code_push_context.block, decls);

    case .DEFER;
        code_defer := cast(*Code_Defer) expr;
        if code_defer.block != null  check_block(code_defer.block, decls);

    case .IF;
        code_if := cast(*Code_If) expr;
        check_expression(code_if.condition, decls);
        if code_if.then_block check_block(code_if.then_block, decls);
        if code_if.else_block check_block(code_if.else_block, decls);

    case .CASE;
        code_case := cast(*Code_Case) expr;
        if code_case.condition != null  check_expression(code_case.condition, decls);
        check_block(code_case.then_block, decls);

    case .WHILE;
        code_while := cast(*Code_While) expr;
        check_expression(code_while.condition, decls);
        check_block(code_while.block, decls);

    case .FOR;
        code_for := cast(*Code_For) expr;

        for_decls_mark := decls.count;
        defer  count_unused_declarations(decls.*, for_decls_mark);
        defer  decls.count = for_decls_mark;

        if code_for.ident_decl != null && code_for.ident_decl.name != "it" {
            array_add(decls, .{decl=code_for.ident_decl});
        }
        if code_for.index_decl != null && code_for.index_decl.name != "it_index" {
            array_add(decls, .{decl=code_for.index_decl});
        }

        // @Incomplete: Also check the want_* expressions.

        check_expression(code_for.iteration_expression, decls);
        if code_for.iteration_expression_right != null {
            check_expression(code_for.iteration_expression_right, decls);
        }

        check_block(code_for.block, decls);

    case .PROCEDURE_CALL;
        // @Incomplete: Also check context_modification.modification_expressions.
        code_proc := cast(*Code_Procedure_Call) expr;
        if code_proc.macro_expansion_block != null  check_block(code_proc.macro_expansion_block, decls);
        check_expression(code_proc.procedure_expression, decls);
        for arg: code_proc.arguments_unsorted {
            check_expression(arg.expression, decls);
        }

    case .LOOP_CONTROL;
        loop_control := cast(*Code_Loop_Control) expr;
        if loop_control.target_ident  check_expression(loop_control.target_ident, decls);

    case .DIRECTIVE_RUN;
        code_run := cast(*Code_Directive_Run) expr;
        check_block(code_run.procedure.body_or_null.block, decls);

    case .BINARY_OPERATOR;
        code_binary := cast(*Code_Binary_Operator) expr;
        check_expression(code_binary.left,  decls);
        check_expression(code_binary.right, decls);

    case .UNARY_OPERATOR;
        code_unary := cast(*Code_Unary_Operator) expr;
        check_expression(code_unary.subexpression, decls);

    case .RETURN;
        code_return := cast(*Code_Return) expr;
        for arg: code_return.arguments_unsorted {
            check_expression(arg.expression, decls);
        }
    case .USING;
        code_using := cast(*Code_Using) expr;
        check_expression(code_using.expression, decls);

    case .CAST;
        code_cast := cast(*Code_Cast) expr;
        check_expression(code_cast.expression, decls);

    case .EXTRACT;
        code_extract := cast(*Code_Extract) expr;
        if code_extract.from  check_expression(code_extract.from, decls);

    case .LITERAL;
        literal := cast(*Code_Literal) expr;
        if literal.value_type == {
        case .POINTER;
            info := literal.pointer_literal_info;
            if info.pointer_literal_type == {
            case .STRING_OR_ARRAY_LITERAL_DATA_POINTER;
                check_expression(info.string_or_array_literal, decls);
            case .GLOBAL_SYMBOL;
                decl := info.global_symbol;
                check_expression(decl, decls);
            }

        case .STRUCT;
            info := literal.struct_literal_info;
            for info.arguments {
                check_expression(it, decls);
            }
        case .ARRAY;
            info := literal.array_literal_info;
            for info.array_members {
                check_expression(it, decls);
            }
        }

    case .COMMA_SEPARATED_ARGUMENTS;
        args := cast(*Code_Comma_Separated_Arguments) expr;
        for args.arguments {
            check_expression(it.node, decls);
        }

    case .COMPOUND_DECLARATION;
        compound := cast(*Code_Compound_Declaration) expr;
        decl := compound.declaration_properties;
        assert(decl != null);
        assert(compound.comma_separated_assignment != null);

        if decl.expression  check_expression(decl.expression, decls);

        if compound.operator_type != 0 {
            // This is a compound binary operator like =, +=, etc.
            check_expression(compound.comma_separated_assignment, decls);
        }

    case .DECLARATION;
        decl := cast(*Code_Declaration) expr;
        if decl.expression  check_expression(decl.expression, decls);

    case .IDENT;
        code_ident := cast(*Code_Ident) expr;

        // @Cleanup: For some Code_Ident's, the resolved_declaration is null for some reason, so we can't
        // track the variable they're referencing.
        // We iterate in reverse in case the resolved_decl is null so we can just pick the first declaration
        // that has the same name.
        for < * decls.* {
            found: bool;
            if code_ident.resolved_declaration != null {
                if it.decl == code_ident.resolved_declaration {
                    found = true;
                }
            } else {
                // Fallback for when resolved_declaration is null.
                if it.decl.name == code_ident.name {
                    found = true;
                }
            }
            if found {
                it.use_count += 1;
                break;
            }
        }
    }
}

count_unused_declarations :: (decls: []Declaration, start: s64 = 0) {
    for i: start..decls.count-1 {
        it := decls[i];
        if it.use_count == 0 {
            loc := make_location(it.decl);
            loc_string := tprint("%:%,%", loc.fully_pathed_filename, loc.line_number, loc.character_number);
            type_string := ifx it.decl.flags & .IS_CONSTANT then "Constant" else "Variable";

            compiler_report(tprint("% '%' is unused.", type_string, it.decl.name), loc, .ERROR_CONTINUABLE);
            context.check_unused_variables_plugin.unused_variables_count += 1;
        }
    }
}
