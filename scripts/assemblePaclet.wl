(* ::Package:: *)

(* ::Section:: *)
(*Assemble the paclet, and build a new .paclet file*)


date = DateString[{"Year", "Month", "Day"}];
time = DateString[{"Hour24", "Minute", "Second"}];


$source = ToFileName[{ParentDirectory[NotebookDirectory[]], "GitLink"}];
$assembled = ToFileName[{NotebookDirectory[], date <> "-" <> time, "GitLink"}];

CreateDirectory[$assembled, CreateIntermediateDirectories -> True];

CopyDirectory[ToFileName[{$source, #}], ToFileName[{$assembled, #}]]& /@ {
	"Documentation",
	"Kernel",
	"LibraryResources"
};

FileTemplateApply[
	FileTemplate[ToFileName[{$source}, "PacletInfoTemplate.m"]],
	<| "date" -> date, "time" -> time |>,
	ToFileName[{$assembled}, "PacletInfo.m"]
];

(* get rid of any .DS* files or other hidden files *)
DeleteFile /@ FileNames[".*", $assembled, Infinity];


PackPaclet[$assembled]


(* ::Input:: *)
(*SystemOpen[ParentDirectory[$assembled]]*)


(* ::Section::Closed:: *)
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

Module[{pacletnames, pacletint, editsites, found},
	pacletnames = {"GitLink", "StashLink"};
	pacletint = "http://paclet-int.wolfram.com:8080/PacletServerInternal";
	editsites = !MemberQ[PacletSites[], _[pacletint, ___]];
	If[editsites, PacletSiteUpdate @ PacletSiteAdd[pacletint]];

	RebuildPacletData[];
	PacletUpdate /@ pacletnames;
	found = # \[Rule] PacletFind[#]& /@ pacletnames;

	If[editsites,
		PacletSiteRemove[pacletint];
		RebuildPacletData[]
	];
	found
]
*)
