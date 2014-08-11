args_helper
====================

ArgsHelper intended to help prototyping, implementation and use of the command-line programs with multiple commands (options and arguments).

Version: 0.0.2

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
ArgsHelperException: Type 'MyProgram' must have a method 'sayHelloCommand' for 'say hello' command.
```

```
ArgsHelperException: Parameter 'String lang' not found in method 'sayHelloCommand'.
```

```
ArgsHelperException: Method 'sayGoodbyeCommand' must contain positional parameter for the arguments.
```

**Usage**

```
dart my_program.dart say hello --lang en --name Jack --name John
Hello, Jack, John! 
```

```
dart my_program.dart say goodbye Jack John
Goodbye, Jack, John! 
```

Another example of command-line program:

```dart
import "package:args_helper/args_helper.dart";
import "package:yaml/yaml.dart" as yaml;

void main(List<String> arguments) {
  var configuration = yaml.loadYaml(_configuration);
  new ArgsHelper<Program>().run(arguments, configuration);
}

class Program {
  void pubGetCommand() {
    _run("pub get", {}, []);
  }

  void pubInstallCommand() {
    _run("pub install", {}, []);
  }

  void pubRunCommand(List executable) {
    _run("pub run", {}, executable);
  }

  void pubUpgradeCommand() {
    _run("pub upgrade", {}, []);
  }

  void pubUploaderAddCommand(List emails, {String package, String server}) {
    var options = {};
    if (package != null) {
      options["package"] = package;
    }

    if (server != null) {
      options["server"] = server;
    }

    _run("pub uploader add", options, emails);
  }

  void pubUploaderRemoveCommand(List emails, {String package, String server}) {
    var options = {};
    if (package != null) {
      options["package"] = package;
    }

    if (server != null) {
      options["server"] = server;
    }

    _run("pub uploader remove", options, emails);
  }

  void _run(String command, Map options, List arguments) {
    print("Command: '$command'");
    print("Options: $options");
    print("Arguments: $arguments");
  }
}

String _configuration =
    '''
name: example_shell
description: Command line program with multiple commands.
commands:
  pub get:
    description: Get all the dependencies.
    options:    
  pub run:
    description: Run a Dart script from the command line.
    rest:
      help: Dart script with an arguments.
      required: true
      usage: executable [args...]
  pub upgrade:
    description: Get the latest versions of all the dependencies. 
  pub uploader add:
    aliases: ["pub add uploader"]
    description: Add uploader for a package on pub.dartlang.org.
    rest:        
      help: Email addresses of the persons to add as an uploaders.
      required: true
      usage: emails    
    options:
      package:
        help: |
              The package whose uploaders will be modified.
              (defaults to the current package)    
      server:
        help: |
              The package server on which the package is hosted.
              (defaults to "https://pub.dartlang.org")
  pub uploader remove:
    aliases: ["pub remove uploader"]
    description: Remove uploader for a package on pub.dartlang.org.
    rest:        
      help: Email addresses of the persons to remove as an uploaders.
      required: true
      usage: emails    
    options:
      package:
        help: |
              The package whose uploaders will be modified.
              (defaults to the current package)    
      server:
        help: |
              The package server on which the package is hosted.
              (defaults to "https://pub.dartlang.org")
''';

```
