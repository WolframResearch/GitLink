(* ::Package:: *)

$Debug = False;


Needs["CCompilerDriver`"]
base = ParentDirectory[NotebookDirectory[]];
src = FileNames["*.cpp", FileNameJoin[{base, "src"}], Infinity];
srcDirs = Select[FileNames["*", FileNameJoin[{base, "src"}]], DirectoryQ];


component = FileNameJoin[{ParentDirectory[base], "Components", "libgit2", "0.28.3"}];
environmentNewSSL = Switch[$OperatingSystem,
	"Windows", "vc141",
	"MacOSX", "libcxx-min10.12",
	"Unix", "scientific6-gcc7.3"
];
environmentOldSSL = environmentNewSSL <> ".ssl100";
libDirsOldSSL = {FileNameJoin[{component, $SystemID, environmentOldSSL}]};
libDirsNewSSL = {FileNameJoin[{component, $SystemID, environmentNewSSL}]};
(* Try to use $InstallationDirecotry as a backup for some libraries *)
AppendTo[libDirsOldSSL, FileNameJoin[{$InstallationDirectory, "SystemFiles", "Libraries", $SystemID}]];
AppendTo[libDirsNewSSL, FileNameJoin[{$InstallationDirectory, "SystemFiles", "Libraries", $SystemID}]];
If[$Debug,
	PrependTo[libDirsNewSSL, FileNameJoin[{component, $SystemID, environmentNewSSL<>".debug"}]]';
	PrependTo[libDirsOldSSL, FileNameJoin[{component, $SystemID, environmentOldSSL<>".debug"}]]
];
libDirsOldSSL = Join[Switch[$OperatingSystem,
	"Windows", {FileNameJoin[{ParentDirectory[base], "Components", "LIBSSH2", "1.8.0", $SystemID, "vc141", "lib"}]},
	"MacOSX", {FileNameJoin[{ParentDirectory[base], "Components", "LIBSSH2", "1.8.0", $SystemID, "libcxx-min10.9", "lib"}]},
	"Unix", {
		FileNameJoin[{ParentDirectory[base], "Components", "OpenSSL", "1.0.2n", $SystemID, "scientific6-gcc4.8", "lib"}],
		FileNameJoin[{ParentDirectory[base], "Components", "LIBSSH2", "1.8.0", $SystemID, "scientific6-gcc4.8", "lib"}],
		FileNameJoin[{ParentDirectory[base], "Components", "libcurl", "7.57.0", $SystemID, "scientific6-gcc4.8", "lib"}]
	},
	_, {}
], libDirsOldSSL];
libDirsNewSSL = Join[Switch[$OperatingSystem,
	"Windows", {FileNameJoin[{ParentDirectory[base], "Components", "LIBSSH2", "1.9.0", $SystemID, "vc141", "lib"}]},
	"MacOSX", {FileNameJoin[{ParentDirectory[base], "Components", "LIBSSH2", "1.9.0", $SystemID, "libcxx-min10.12", "lib"}]},
	"Unix", {
		FileNameJoin[{ParentDirectory[base], "Components", "OpenSSL", "1.1.1c", $SystemID, "scientific6-gcc4.8", "lib"}],
		FileNameJoin[{ParentDirectory[base], "Components", "LIBSSH2", "1.9.0", $SystemID, "scientific6-gcc4.8", "lib"}]
	},
	_, {}
], libDirsNewSSL];
includeDir = FileNameJoin[{component, "Source", "include"}];
compileOpts = "";


compileOpts = Switch[$OperatingSystem,
	"Windows", "/EHsc /MT" <> If[$Debug, "D", ""],
	"MacOSX", "-std=c++14 -stdlib=libc++ -mmacosx-version-min=10.12 -framework Security",
	"Unix", "-Wno-deprecated -std=c++14"];
linkerOpts = Switch[$OperatingSystem,
	"Windows", "/NODEFAULTLIB:msvcrt",
	_, ""];
oslibs = Switch[$OperatingSystem,
	"Windows", {"advapi32", "ole32", "rpcrt4", "shlwapi", "user32", "winhttp", "crypt32", "libssh2"},
	"MacOSX", {"z", "iconv", "crypto", "ssh2"},
	"Unix", {"z", "rt", "pthread", "ssh2", "ssl"}
];
defines = {Switch[$OperatingSystem,
	"Windows", "WIN",
	"MacOSX", "MAC",
	"Unix", "UNIX"]};
If[$SystemWordLength===64, AppendTo[defines, "SIXTYFOURBIT"]];
If[$Debug, AppendTo[defines, "DEBUG"]];


destDir = FileNameJoin[{base, "GitLink", "LibraryResources", $SystemID}];
If[!DirectoryQ[destDir], CreateDirectory[destDir]];


libNewSSL = CreateLibrary[src, "gitLink",
(*	"ShellOutputFunction"->Print,*)
	"Debug"->$Debug,
	"TargetDirectory"->destDir,
	"Language"->"C++",
	"CompileOptions"->compileOpts,
	"Defines"->defines,
	"LinkerOptions"->linkerOpts,
	"IncludeDirectories"->Flatten[{includeDir, srcDirs}],
	"LibraryDirectories"->libDirsNewSSL,
	"Libraries"->Prepend[oslibs, "git2"]
]


libOldSSL = CreateLibrary[src, "gitLink_ssl100",
(*	"ShellOutputFunction"->Print,*)
	"Debug"->$Debug,
	"TargetDirectory"->destDir,
	"Language"->"C++",
	"CompileOptions"->compileOpts<>If[$OperatingSystem==="MacOSX"," -mmacosx-version-min=10.9",""],
	"Defines"->defines,
	"LinkerOptions"->linkerOpts,
	"IncludeDirectories"->Flatten[{includeDir, srcDirs}],
	"LibraryDirectories"->libDirsOldSSL,
	"Libraries"->Prepend[oslibs, "git2"]
]
