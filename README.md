args_helper
====================

ArgsHelper intended to help prototyping, implementation and use of the command-line programs with multiple commands (options and arguments).

Version: 0.0.8

**Prototyping**

Prototyping is done by creating a commands specification. Usually this can be done in an easy to understand format.

For example, possible use `yaml` format.

```
name: my_program
description: My program
commands:
  say hello:
    description: Says hello
    options:
      name:
        help: Your names
        allowMultiple: true
        required: true
      lang:
        help: Say hello in language
        allowed: [en, ru]
        defaultsTo: en
  say goodbye:
    description: Says goodbye
    rest:
      allowMultiple: false
      name: name
      required: true        
```

**Implementation**

The implementation process can be called slightly importunate. This means that the developed prototype will not work until you have implemented all the methods for all commands.

Automatically (on each start of program) performed the following operations:

- Validation of the methods, which are responsible for the commands.
- Validation of the method parameters, which are responsible for the command options.

This means that unimplemented and partially implemented commands not allowed.

Source code of the program for prototyped the command specification.

```dart
import "package:args_helper/args_helper.dart";
import "package:yaml/yaml.dart" as yaml;

void main(List<String> arguments) {
  var configuration = yaml.loadYaml(_configuration);
  new ArgsHelper<MyProgram>().run(arguments, configuration);
}

class MyProgram {
  void sayHelloCommand({String lang, List name}) {
    var hello = "Hi";
    switch (lang) {
      case "en":
        hello = "Hello";
        break;
      case "ru":
        hello = "Привет";
        break;
    }

    print("$hello, ${name.join(", ")}!");
  }

  void sayGoodbyeCommand(String name) {
    print("Goodbye, ${name}!");
  }
}

String _configuration =
    '''
name: my_program
description: My program
commands:
  say hello:
    description: Says hello
    options:
      name:
        help: Your name
        allowMultiple: true
        required: true       
      lang:
        help: Say hello in language
        allowed: [en, ru]
        defaultsTo: en
  say goodbye:
    description: Says goodbye
    rest:
      allowMultiple: false
      name: name
      required: true      
''';

```

Examples of exceptions in case of deviations from the specification.

```
Type 'MyProgram' must have a method 'sayHelloCommand' for 'say hello' command.
```

```
Parameter 'String lang' not found in method 'sayHelloCommand'.
```

```
Method 'sayGoodbyeCommand' must contain positional parameter for the arguments.
```

**Usage**

```
> my_program say hello --lang en --name Jack --name John
Hello, Jack, John! 
```

```
> my_program say goodbye Jack John
Goodbye, Jack, John! 
```

**Format**

Format of specification is the following:

```yaml
name: # name of program
description: # description of program
commands: # commands of program
  command_name: # command
    description: # description of command          
    options: # options of command
      option_name: # option
        # option attributes
    rest: # remaining arguments of command
      allowMultiple # Indicates that multiple arguments allowed or not
      help: # help on the rest
      name: # name used for generating the string "usage"
      required: # indicates whatever required or not 
      usage: # usage of the rest        
```

**Option attributes**

Specification of `options` is based on the `args` package.

List of all supported attributes of the options:

- abbr
- allowed
- allowedHelp
- allowMultiple
- defaultsTo
- help
- hide
- negatable
- valueHelp

Default values of the attributes depends on the type of the option (flag or option) and used the values as in the `args` package.

Additional attributes:

- `isFlag` indicates that the option is a flag or not
- `required` indicates that the option is required or not

**Rest attributes**

The `rest` attribute of the command used for configuring the remaining command arguments (rest).

List of the `rest `attributes:

- `allowMultiple` indicates that multiple arguments allowed or not
- `help` text on these remaining arguments
- `name` used for generating the string "usage"
- `required` indicates that the remaining arguments are required or not
- `usage` text on these remaining arguments