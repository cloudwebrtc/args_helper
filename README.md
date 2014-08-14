args_helper
====================

ArgsHelper intended to help prototyping, implementation and use of the command-line programs with multiple commands (options and arguments).

Version: 0.0.4

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
      lang:
        help: Say hello in language
        allowed: [en, ru]
        defaultsTo: en
  say goodbye:
    description: Says goodbye
    rest:
      usage: names
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

    var people = (name == null ? ["brother"] : name).join(", ");
    print("$hello, $people!");
  }

  void sayGoodbyeCommand(List names) {
    var people = names.join(", ");
    print("Goodbye, $people!");
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
        help: Your names
        allowMultiple: true
      lang:
        help: Say hello in language
        allowed: [en, ru]
        defaultsTo: en
  say goodbye:
    description: Says goodbye
    rest:
      usage: names
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
    rest: # remaining arguments of command
      help: # help on the rest
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

Additional attribute that indicates that the option is a flag or not.

- isFlag