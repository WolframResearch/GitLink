(* ::Package:: *)

(* ::Title:: *)
(*Assemble the paclet, and build a new .paclet file*)


(* ::Section:: *)
(*Find directory locations*)


date = DateString[{"Year", "Month", "Day"}];
time = DateString[{"Hour24", "Minute", "Second"}];

(* TeamCity should set the version number using a timestamp and build number, in the SET_VERSION_NUMBER environment variable *)
$versionNumber = If[Environment["SET_VERSION_NUMBER"] =!= $Failed,
	Environment["SET_VERSION_NUMBER"],
	"0.0."<>date<>"."<>time
];

(* TeamCity should set the workspace location in the WORKSPACE environment variable *)
$workspaceDirectory = Which[
	Environment["WORKSPACE"] =!= $Failed,
		Environment["WORKSPACE"],
	$InputFileName =!= "",
		DirectoryName[$InputFileName],
	True,
		NotebookDirectory[]
];

(* The location of the Kernel files should be ./GitLink/GitLink/Kernel *)
$kernelDirectory = FileNameJoin[{$workspaceDirectory,"GitLink","GitLink","Kernel"}];

(* The PacletInfoTemplate.m file should be in the directory above the Kernel files *)
$templateFile = FileNameJoin[{ParentDirectory[$kernelDirectory], "PacletInfoTemplate.m"}];

(* Where to find inputs provided by chain builds *)
$inputDirectory = FileNameJoin[{$workspaceDirectory,"output","Files"}];

(* Where to output the paclet file *)
$outputDirectory = FileNameJoin[{$workspaceDirectory, "output"}];

(* Where to assemble GitLink *)
$assembled = FileNameJoin[{$workspaceDirectory,"output","Files", date <> "-" <> time, "assembled", "GitLink"}];

CreateDirectory[$assembled, CreateIntermediateDirectories -> True];


(* ::Section:: *)
(*Copy files to be assembled into assembly directory*)


CopyDirectory[$kernelDirectory, FileNameJoin[{$assembled, "Kernel"}]];
CopyDirectory[FileNameJoin[{$inputDirectory, "GitLink", "Documentation"}], FileNameJoin[{$assembled, "Documentation"}]];
CopyDirectory[FileNameJoin[{$inputDirectory, "GitLink", "LibraryResources"}], FileNameJoin[{$assembled, "LibraryResources"}]];


(* ::Section:: *)
(*Assemble the paclet*)


(* Pull SystemID/Qualifier from environment if they exist, otherwise leave them empty for MULT build *)
$systemID = Which[
	Environment["SYSTEM_ID"] =!= $Failed && Environment["SYSTEM_ID"] =!= "any",
		"SystemID -> \"" <> Environment["SYSTEM_ID"] <> "\",",
	True,
		""
	];
	
$qualifier = Which[
	Environment["QUALIFIER"] =!= $Failed && Environment["QUALIFIER"] =!= "any",
		"Qualifier -> \"" <> Environment["QUALIFIER"] <> "\",",
	True,
		""
	];

(* Fill the template info file with information about this build *)
FileTemplateApply[
	FileTemplate[$templateFile],
	<| "Version" -> $versionNumber, "SystemID" -> $systemID, "Qualifier" -> $qualifier |>,
	FileNameJoin[{$assembled, "PacletInfo.m"}]
];

(* get rid of any .DS* files or other hidden files *)
DeleteFile /@ FileNames[".*", $assembled, Infinity];


(* ::Section:: *)
(*Create .paclet file*)


PackPaclet[$assembled];
(* Copy the assembled paclet into the output directory *)
$pacletName = FileNameTake[FileNames["*.paclet",ParentDirectory[$assembled]][[1]]];
CopyFile[
	FileNameJoin[{ParentDirectory[$assembled], $pacletName}],
	FileNameJoin[{$outputDirectory, $pacletName}]
];


(* ::Section:: *)
(*notes*)


(*
Re version numbering:

The code above which builds the .paclet file starts from a PacletInfoTemplate.m
file, and creates a new PacletInfo.m file, using the current date and time as
part of a newly synthesized version number.

One consequence of this is that the static PacletInfo.m file will not be used,
except by developers who install the original source of GitLink, which should be
limited to only people who are developing GitLink.

For this reason, the version number in the static PacletInfo.m file should
always be greater than the version number synthesized here. That way, GitLink
developers can install the original source, and have it preferred over versions
of this paclet installed from the internal paclet server.
*)


(*
To deploy a .paclet file to the internal paclet server:

--
% scp GitLink-x.y.z.paclet username@paclet-int:/mnt/paclets/to-deploy/internal/.

% ssh paclet-int

paclet-int% ls -la /mnt/paclets/to-deploy/internal

paclet-int% cd /PacletProcessing/PacletSystem/Paclet-Int/scripts/

paclet-int% ant pushInternal
--

It's not uncommon for this ant script to take 40 minutes or more to complete.
*)


(*
To install / update from the internal paclet server:

PacletManager`PacletUpdate[#1,"Site"->"http://paclet-int.wolfram.com:8080/PacletServerInternal"]& /@
  {"GitLink", "StashLink"}
*)
