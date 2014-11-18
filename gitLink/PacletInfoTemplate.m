
Paclet[
    Name -> "gitLink",
    Version -> "0.0.`date`.`time`",
    MathematicaVersion -> "10+",
    Root -> ".",
    Internal -> True,
    Extensions -> 
        {
            {"Kernel", Root -> ".", Context -> "gitLink`"},

            {"Documentation", Language -> "English"},

			{"Resource", SystemID ->"Linux-x86-64", Resources -> {
				{"gitLink.so", "LibraryResources/Linux-x86-64/gitLink.so"}
			}},

			{"Resource", SystemID ->"MacOSX-x86-64", Resources -> {
				{"gitLink.dylib", "LibraryResources/MacOSX-x86-64/gitLink.dylib"}
			}},

			{"Resource", SystemID ->"Windows-x86-64", Resources -> {
				{"gitLink.dll", "LibraryResources/Windows-x86-64/gitLink.dll"},
				{"gitLink.exp", "LibraryResources/Windows-x86-64/gitLink.exp"},
				{"gitLink.lib", "LibraryResources/Windows-x86-64/gitLink.lib"}
			}}
        }
]
