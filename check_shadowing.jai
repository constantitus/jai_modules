// Source: https://gist.github.com/mvandevander/bb4c5deb71395499790c4451fb27a1f2
// 
// The implementation of this shadow checker plugin starts from each procedure and recurses on imperative
// scopes within that procedure, checking local variable declarations against other local variable declarations
// in the procedure. This is 95% of what you want.
//
// Each procedure is checked as soon as it is compiled. This is nice because it means #run directives
// will be checked before they're executed. However, this choice allows a procedure to shadow variables
// outside its declaration (globals, etc) without this plugin detecting them.
//
// There is a special case related to it/it_index shadowing. When nesting loops, it is common to leave
// these variables implicitly named. This would technically be a shadowing error, but it is done commonly
// and it isn't really a problem unless the variables are referenced. This plugin currently does not check
// loop variables named it/it_index.
//
// There is a special case related to procedures shadowing procedures. This plugin cannot distinguish
// overloads from shadowing. There are some cases where you can shadow a specific member of an overload
// group in a way that aught to be a shadowing error, but it won't be detected here.
//
// There is a special case related to procedural scopes. If a declaration is in a procedural block, it
// cannot shadow declaration that happen on later line numbers in the same block
//
// Imported identifiers can be shadowed without this plugin detecting them.
//
// Uncompiled procedures aren't checked (dead code elimination, polymorphic procedures that aren't called).
//
// Inactive #if blocks aren't checked.


Check_Shadowing_Plugin :: struct {
    #as using plugin: Metaprogram_Plugin;
    check_jai_modules: bool;
    excluded_paths: [..]string;
}

message :: (p: *Metaprogram_Plugin, message: *Message) {
    check_shadowing_plugin := cast(*Check_Shadowing_Plugin)p;
    if message.kind == {
    case .TYPECHECKED;
        code := cast(*Message_Typechecked)message;
        for code.procedure_bodies {
            // This plugin operates on procedure bodies. This will exclude any macro, polymorphic declaration
            // (the instantiated polymorphs still appear), and procedure that is omitted by dead code elimination.

            procedure_header := it.expression.header;

            is_jai_modules := String.contains(procedure_header.enclosing_load.enclosing_import.fully_pathed_filename, "jai/modules/");
            is_excluded_path := false;
            for check_shadowing_plugin.excluded_paths {
                if String.contains(procedure_header.enclosing_load.enclosing_import.fully_pathed_filename, it) {
                    is_excluded_path = true;
                    break;
                }
            }
            check_module := true;
            if is_excluded_path {
                check_module = false;
            }
            if is_jai_modules && !check_shadowing_plugin.check_jai_modules {
                check_module = false;
            }
            if check_module {
                check_procedure(procedure_header);
            }
        }
    }
}

init :: (p: *Metaprogram_Plugin, options: []string) -> bool {
    check_shadowing_plugin := cast(*Check_Shadowing_Plugin)p;

    for options
    {
        if it == {
        case "-check_jai_modules";
            check_shadowing_plugin.check_jai_modules = true;
        case "-exclude_module_path";
            log("found exclude module path option to plugin %", options[it_index + 1]);
            if it_index >= options.count-1 {
                log_error("Missing argument to -exclude_module_path");
            }
            array_add(*check_shadowing_plugin.excluded_paths, options[it_index + 1]);
        }
    }
    return true;
}

log_help :: (p: *Metaprogram_Plugin) {
    log(HELP_STRING);
}

HELP_STRING :: #string DONE
    This plugin examines each procedure as it is compiled, and produces compilation errors when variables are found to shadow other variables. By default, it will run on every procedure in your modules and in your main program.
        -check_jai_modules         This will perform shadow checking on "jai/modules/" as well.
        -exclude_module_path src/  This will exclude modules containing the path "src/", for example.

DONE

get_plugin :: () -> *Metaprogram_Plugin {
    p := New(Check_Shadowing_Plugin);

    p.before_intercept  = null; // Not needed.
    p.add_source        = null; // Not needed.
    p.message           = message;
    p.finish            = null; // Not needed.
    p.shutdown          = null; // Not needed.
    p.init = init;
    // p.handle_one_option = handle_one_option;
    p.log_help          = log_help;

    return p;
}

#scope_file

check_procedure :: (header: *Code_Procedure_Header) {
    variables: [..]*Code_Declaration;

    for constant: header.constants_block.members {
        assert(constant.kind == .DECLARATION);
        constant_declaration := cast(*Code_Declaration)constant;
        check_variable(constant_declaration, *variables, header.body_or_null.block);
        array_add(*variables, constant_declaration);
    }
    for argument: header.arguments {
        check_variable(argument, *variables, header.body_or_null.block);
        array_add(*variables, argument);
    }
    check_block(header.body_or_null.block, *variables);
}

check_block :: (block: *Code_Block, variables: *[..]*Code_Declaration) {
    variable_stack_mark := variables.count;
    for member: block.members {
        assert(member.kind == .DECLARATION);
        member_declaration := cast(*Code_Declaration)member;
        check_variable(member_declaration, variables, block);
        array_add(variables, member_declaration);
    }
    for statement: block.statements {
        if statement.kind == {
        case .PROCEDURE_CALL;
            proc_call := cast(*Code_Procedure_Call, statement);
            if(proc_call.macro_expansion_block != null) check_block(proc_call.macro_expansion_block, variables);
        case .BLOCK;
            check_block(cast(*Code_Block)statement, variables);
        case .PUSH_CONTEXT;
            block := (cast(*Code_Push_Context)statement).block;
            if block != null  check_block(block, variables);
        case .DEFER;
            block := (cast(*Code_Defer)statement).block;
            if block != null  check_block(block, variables);
        case .WHILE;
            check_block((cast(*Code_While)statement).block, variables);
        case .IF;
            if_statement := cast(*Code_If)statement;
            if if_statement.then_block check_block(if_statement.then_block, variables);
            if if_statement.else_block check_block(if_statement.else_block, variables);
        case .CASE;
            check_block((cast(*Code_Case)statement).then_block, variables);
        case .FOR;
            for_statement := cast(*Code_For)statement;
            for_variables_mark := variables.count;
            // The built-in for loops in this language go out of their way to omit loop variables.
            // A range based loop will not have an 'it_index' or index_decl, and a normal loop that doesn't
            // use 'it' will not have an ident_decl.
            if for_statement.ident_decl {
                // Don't check if a loop iterator variable named 'it' shadows other variables.
                if for_statement.ident_decl.name != "it" {
                    check_variable(for_statement.ident_decl, variables, block);
                }
                array_add(variables, for_statement.ident_decl);
            }
            if for_statement.index_decl {
                // Don't check if a loop index variable named 'it_index' shadows other variables.
                if for_statement.index_decl.name != "it_index" {
                    check_variable(for_statement.index_decl, variables, block);
                }
                array_add(variables, for_statement.index_decl );
            }
            check_block(for_statement.block, variables);
            variables.count = for_variables_mark;
        }
    }
    variables.count = variable_stack_mark;
}

check_variable :: (variable: *Code_Declaration, variables: *[..]*Code_Declaration, block: *Code_Block) {
    for variables.* {
        if variable.name == it.name {
            if variable.type.type == .PROCEDURE && it.type.type == .PROCEDURE {
                // Overloaded procedure, not shadowing.
                continue;
            }
            location1 := make_location(variable);
            location2 := make_location(it);
            if(block != null && block.block_type == .IMPERATIVE && location2.line_number > location1.line_number) {
                return; // not true shadowing because the second definition is after this in imperative scope!
            }
            location1_string := tprint("%:%,%",location1.fully_pathed_filename, location1.line_number, location1.character_number);
            location2_string := tprint("%:%,%",location2.fully_pathed_filename, location2.line_number, location2.character_number);
            compiler_report(tprint("A variable '%' shadows a variable at \n%.", variable.name, location2_string), location1, .ERROR_CONTINUABLE);
        }
    }
}

#import "Compiler";
#import "Basic";
String :: #import "String";
