(* ::Package:: *)

$Debug = False;


Needs["CCompilerDriver`"]
base = ParentDirectory[NotebookDirectory[]];
src = FileNames["*.cpp", FileNameJoin[{base, "src"}], Infinity];
srcDirs = Select[FileNames["*", FileNameJoin[{base, "src"}]], DirectoryQ];


component = FileNameJoin[{ParentDirectory[base], "Components", "libgit2", "0.26.0"}];
environment = Switch[$OperatingSystem,
	"Windows", "vc153",
	"MacOSX", "highsierra-clang9.0",
	"Unix", "scientific6-gcc7.2"];
libDirs = {FileNameJoin[{$InstallationDirectory, "SystemFiles", "Libraries", $SystemID}],FileNameJoin[{component, $SystemID}], FileNameJoin[{component, $SystemID, environment}]};
If[$Debug, PrependTo[libDirs, FileNameJoin[{component, $SystemID, environment<>".debug"}]]];
libDirs = Join[Switch[$OperatingSystem,
	"Windows", {FileNameJoin[{ParentDirectory[base], "Components", "LIBSSH2", "1.8.0", $SystemID, "vc141", "lib"}]},
	"MacOSX", {FileNameJoin[{ParentDirectory[base], "Components", "LIBSSH2", "1.8.0", $SystemID, "libcxx-min10.9", "lib"}]},
	"Unix", {
		FileNameJoin[{ParentDirectory[base], "Components", "OpenSSL", "1.0.2n", $SystemID, "scientific6-gcc4.8", "lib"}],
		FileNameJoin[{ParentDirectory[base], "Components", "LIBSSH2", "1.8.0", $SystemID, "scientific6-gcc4.8", "lib"}],
		FileNameJoin[{ParentDirectory[base], "Components", "libcurl", "7.57.0", $SystemID, "scientific6-gcc4.8", "lib"}]
	},
	_, {}
], libDirs];
includeDir = FileNameJoin[{component, "Source", "include"}];
compileOpts = "";


compileOpts = Switch[$OperatingSystem,
	"Windows", "/EHsc /MT" <> If[$Debug, "D", ""],
	"MacOSX", "-std=c++14 -stdlib=libc++ -mmacosx-version-min=10.9 -framework Security",
	"Unix", "-Wno-deprecated -std=c++14"];
linkerOpts = Switch[$OperatingSystem,
	"Windows", "/NODEFAULTLIB:msvcrt",
	_, ""];
oslibs = Switch[$OperatingSystem,
	"Windows", {"advapi32", "ole32", "rpcrt4", "shlwapi", "user32", "winhttp", "crypt32", "libssh2"},
	"MacOSX", {"z", "iconv", "curl", "crypto", "ssh2"},
	"Unix", {"z", "rt", "pthread", "ssh2", "ssl", "curl"}
];
defines = {Switch[$OperatingSystem,
	"Windows", "WIN",
	"MacOSX", "MAC",
	"Unix", "UNIX"]};
If[$SystemWordLength===64, AppendTo[defines, "SIXTYFOURBIT"]];
If[$Debug, AppendTo[defines, "DEBUG"]];


destDir = FileNameJoin[{base, "GitLink", "LibraryResources", $SystemID}];
If[!DirectoryQ[destDir], CreateDirectory[destDir]];


lib = CreateLibrary[src, "gitLink",
(*	"ShellOutputFunction"->Print,*)
	"Debug"->$Debug,
	"TargetDirectory"->destDir,
	"Language"->"C++",
	"CompileOptions"->compileOpts,
	"Defines"->defines,
	"LinkerOptions"->linkerOpts,
	"IncludeDirectories"->Flatten[{includeDir, srcDirs}],
	"LibraryDirectories"->libDirs,
	"Libraries"->Prepend[oslibs, "git2"]
]



