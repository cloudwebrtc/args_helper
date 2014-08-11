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
