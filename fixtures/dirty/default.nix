{pkgs,lib}: let
  unused = "меня никто не зовёт";
     name = "dirty";
  in {
   pkgs = pkgs;
   upper = value: lib.strings.toUpper value;
   label = ( "фикстура " + name );
   makeName = suffix: name;
}
