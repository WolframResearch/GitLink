(* Wolfram Language Package *)

$Debug = False;
Needs[ "CCompilerDriver`" ];

$GitLink = FileNameJoin[ { DirectoryName[ $InputFileName, 2 ], "src" } ];

$workspace = DirectoryName[ $InputFileName, 3 ];
$libcurl = FileNameJoin[ { $workspace, "libcurl" } ];
$libgit2 = FileNameJoin[ { $workspace, "libgit2" } ];
$libssh2 = FileNameJoin[ { $workspace, "LIBSSH2" } ];
$openssl = FileNameJoin[ { $workspace, "OpenSSL" } ];

$mathlink = FileNameJoin[ { $InstallationDirectory, "SystemFiles", "Links", "MathLink", "DeveloperKit", $SystemID } ];

AntLog[ StringRepeat[ "=", 75 ] ];
AntLog[ "        component == \"" <> AntProperty[ "component" ] <> "\"" ];
AntLog[ "        system_id == \"" <> AntProperty[ "system_id" ] <> "\"" ];
AntLog[ "" ];
AntLog[ "  files_directory == \"" <> AntProperty[ "files_directory" ] <> "\"" ];
AntLog[ "scratch_directory == \"" <> AntProperty[ "scratch_directory" ] <> "\"" ];
AntLog[ "" ];
AntLog[ "         $GitLink == \"" <> $GitLink <> "\"" ];
AntLog[ "         $libcurl == \"" <> $libcurl <> "\"" ];
AntLog[ "         $libgit2 == \"" <> $libgit2 <> "\"" ];
AntLog[ "         $libssh2 == \"" <> $libssh2 <> "\"" ];
AntLog[ "         $openssl == \"" <> $openssl <> "\"" ];
AntLog[ "" ];
AntLog[ "        $mathlink == \"" <> $mathlink <> "\"" ];
AntLog[ StringRepeat[ "=", 75 ] ];
AntLog[ "" ];

$GitLinkLib = CreateLibrary[

	FileNames[ "*.cpp", { $GitLink }, Infinity ],
	"gitLink",

	"CleanIntermediate" -> True,

	"CompileOptions" -> Switch[ $OperatingSystem,
		"MacOSX",	"-std=c++14 -stdlib=libc++ -mmacosx-version-min=10.9 -framework Security",
		"Unix",		"-Wno-deprecated -std=c++14",
		"Windows",	"/EHsc " <> If[ $Debug, "/MTd", "/MT" ]
		],

	"CompilerInstallation" -> If[ $OperatingSystem == "Windows",
		Environment[ "COMPILER_INSTALLATION" ],
		Automatic
		],

	"CompilerName" -> Automatic,

	"Debug" -> $Debug,

	"Defines" -> {
		Switch[ $OperatingSystem,
			"MacOSX",	"MAC",
			"Unix",		"UNIX",
			"Windows",	"WIN"
			],
		If[ $SystemWordLength === 64, "SIXTYFOURBIT", Nothing ],
		If[ $Debug, "DEBUG", Nothing ]
		},

	"IncludeDirectories" -> Flatten[ {
		FileNameJoin[ { $libgit2, "Source", "include" } ],
		Select[ FileNames[ "*", $GitLink ], DirectoryQ ]
		} ],

	"Language" -> "C++",

	"Libraries" -> Switch[ $OperatingSystem,
		"MacOSX",
			{ "git2", "z", "iconv", "curl", "crypto", "ssh2" },
		"Unix",
			{ "git2", "z", "rt", "pthread", "ssh2", "ssl", "curl" },
		"Windows",
			{ "git2", "advapi32", "ole32", "rpcrt4", "shlwapi", "user32", "winhttp", "crypt32", "libssh2" }
		],

	"LibraryDirectories" -> Switch[ $OperatingSystem,
		"MacOSX",
			{
			FileNameJoin[ { $libssh2, "lib" } ],
			FileNameJoin[ { $openssl, "lib" } ],(*for crypto library*)
			$libgit2 <> If[ $Debug, ".debug", "" ]
			},
		"Unix",
			{
			FileNameJoin[ { $openssl, "lib" } ],
			FileNameJoin[ { $libssh2, "lib" } ],
			FileNameJoin[ { $libcurl, "lib" } ],
			$libgit2 <> If[ $Debug, ".debug", "" ]
			},
		"Windows",
			{
			FileNameJoin[ { $libssh2, "lib" } ],
			$libgit2 <> If[ $Debug, ".debug", "" ]
			}
		],

	"LinkerOptions" -> Switch[$OperatingSystem,
		"MacOSX",   { },
		"Unix",     { },
		"Windows",  { "/NODEFAULTLIB:msvcrt" }
		],

	"ShellCommandFunction" -> Global`AntLog,
	"ShellOutputFunction" -> Global`AntLog,

	"SystemIncludeDirectories" -> {
		FileNameJoin[ { $mathlink, "CompilerAdditions" } ],
		FileNameJoin[ { $InstallationDirectory, "SystemFiles", "IncludeFiles", "C" } ]
		},

	"SystemLibraryDirectories" -> {
		If[ $OperatingSystem == "MacOSX" , "-F", "" ] <> FileNameJoin[ { $mathlink, "CompilerAdditions" } ],
		FileNameJoin[ { $InstallationDirectory, "SystemFiles", "Libraries", $SystemID } ]
		},

	"TargetDirectory" -> FileNameJoin[ { AntProperty[ "files_directory" ], AntProperty[ "component" ], "LibraryResources", AntProperty[ "system_id" ] } ],
	"TargetSystemID" -> AntProperty[ "system_id" ],

	"WorkingDirectory" -> AntProperty[ "scratch_directory" ]

	];

If[ FailureQ[ $GitLinkLib ],
	AntFail[ "Library was not generated." ],
	AntLog[ "$GitLinkLib == \"" <> $GitLinkLib <> "\"" ]
	];
