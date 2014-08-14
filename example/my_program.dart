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
