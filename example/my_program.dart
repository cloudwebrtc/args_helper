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
