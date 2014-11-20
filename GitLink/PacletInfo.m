
Paclet[
    Name -> "GitLink",
    Version -> "0.1.0",
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
				{"gitLink.dll", "LibraryResources/Windows-x86-64/gitLink.dll"}
			}},

			{"Resource", SystemID ->"Windows-x86-64", Resources -> {
				{"gitLink.dll", "LibraryResources/Windows-x86-64/gitLink.dll"}
			}}
        }
]
