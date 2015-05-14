(* ::Package:: *)

$Debug = False;


Needs["CCompilerDriver`"]
base = ParentDirectory[NotebookDirectory[]];
src = FileNames["*.cpp", FileNameJoin[{base, "src"}], Infinity];
srcDirs = Select[FileNames["*", FileNameJoin[{base, "src"}]], DirectoryQ];


component = FileNameJoin[{ParentDirectory[base], "Components", "libgit2", "0.22.2"}];
environment = Switch[$OperatingSystem,
	"Windows", "vc120",
	"MacOSX", "mavericks-clang6.0",
	"Unix", "centos5-gcc4.4"];
libDirs = {FileNameJoin[{component, $SystemID}], FileNameJoin[{component, $SystemID, environment}]};
If[$Debug, PrependTo[libDirs, FileNameJoin[{component, $SystemID, environment<>".debug"}]]];
includeDir = FileNameJoin[{component, "Source", "include"}];
compileOpts = "";


compileOpts = Switch[$OperatingSystem,
	"Windows", "/EHsc /MT" <> If[$Debug, "D", ""],
	"MacOSX", "-std=c++11 -stdlib=libc++ -mmacosx-version-min=10.7",
	"Unix", "-Wno-deprecated -std=c++11"];
linkerOpts = Switch[$OperatingSystem,
	"Windows", "/NODEFAULTLIB:msvcrt",
	_, ""];
oslibs = Switch[$OperatingSystem,
	"Windows", {"advapi32", "ole32", "user32", "shlwapi"},
	"MacOSX", {"ssl", "z", "iconv", "crypto"},
	 "Unix", {"ssl", "crypto", "z", "dl", "rt"}
];
defines = {Switch[$OperatingSystem,
	"Windows", "WIN",
	"MacOSX", "MAC",
	"Unix", "UNIX"]};
If[$SystemWordLength===64, AppendTo[defines, "SIXTYFOURBIT"]];


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


If[!MemberQ[$LibraryPath, destDir], PrependTo[$LibraryPath, destDir]];
