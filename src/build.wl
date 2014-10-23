(* ::Package:: *)

Needs["CCompilerDriver`"]
base = ParentDirectory[NotebookDirectory[]];
src = FileNames["*.cpp", FileNameJoin[{base, "src"}], Infinity];
srcDirs = Select[FileNames["*", FileNameJoin[{base, "src"}]], DirectoryQ];


component = FileNameJoin[{ParentDirectory[base], "Components", "libgit2", "0.21.1"}];
libDirs = {FileNameJoin[{component, $SystemID}]};
includeDir = FileNameJoin[{component, "Source", "include"}];
compileOpts = "";


compileOpts = Switch[$OperatingSystem,
	"Windows", "/MT /EHsc",
	"MacOSX", "-std=c++11",
	"Unix", "-Wno-deprecated"];
linkerOpts = Switch[$OperatingSystem,
	"Windows", "/NODEFAULTLIB:msvcrt",
	_, ""];
oslibs = Switch[$OperatingSystem,
	"Windows", {"advapi32", "ole32", "user32", "shlwapi"},
	"MacOSX", {"ssl", "z", "iconv", "crypto"},
	"Unix", {"z", "dl", "rt"}
];
defines = {Switch[$OperatingSystem,
	"Windows", "WIN",
	"MacOSX", "MAC",
	"Unix", "UNIX"]};
If[$SystemWordLength===64, AppendTo[defines, "SIXTYFOURBIT"]];


destDir = FileNameJoin[{base, "gitLink", "LibraryResources", $SystemID}];
If[!DirectoryQ[destDir], CreateDirectory[destDir]];


lib = CreateLibrary[src, "gitLink",
	"ShellOutputFunction"->Print,
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
