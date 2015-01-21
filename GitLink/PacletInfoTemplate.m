(* ::Package:: *)

Paclet[
    Name -> "GitLink",
    Version -> "`version`",
    MathematicaVersion -> "10+",
    Root -> ".",
    Internal -> True,
    Extensions -> 
        {
            {"Kernel", Root -> ".", Context -> "GitLink`"},

            {"Documentation", Language -> "English"},

			{"Resource", SystemID ->"Linux-x86-64", Resources -> {
				{"gitLink.so", "LibraryResources/Linux-x86-64/gitLink.so"}
			}},

			{"Resource", SystemID ->"MacOSX-x86-64", Resources -> {
				{"gitLink.dylib", "LibraryResources/MacOSX-x86-64/gitLink.dylib"}
			}},

			{"Resource", SystemID ->"Windows", Resources -> {
				{"gitLink.dll", "LibraryResources/Windows/gitLink.dll"}
			}},

			{"Resource", SystemID ->"Windows-x86-64", Resources -> {
				{"gitLink.dll", "LibraryResources/Windows-x86-64/gitLink.dll"}
			}}
        }
]
