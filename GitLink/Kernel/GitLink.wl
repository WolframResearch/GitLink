(* ::Package:: *)

(* ::Section:: *)
(*Implementation*)


(* ::Subsection::Closed:: *)
(*Package header*)


BeginPackage["GitLink`"];


$GitLibraryPath;
$GitLibraryInformation;
InitializeGitLibrary;

GitRepoQ;
GitRemoteQ;
GitBranchQ;
GitCommitQ;
GitProperties;
GitCommitProperties;
GitStatus;
GitSHA;
GitRange;
GitSignature;
GitType;
ToGitObject;

GitRepo;
GitObject;
GitOpen;
GitClone;
GitFetch;
GitPush;
GitCherryPick;
GitMerge;
GitCreateBranch;
GitDeleteBranch;
GitMoveBranch;
GitUpstreamBranch;
GitSetUpstreamBranch;
GitAddRemote;
GitDeleteRemote;
GitCheckout;

GitTreeExpand;

GitRepoList;
ManageGitRepoList;

ShowRepoViewer;


Begin["`Private`"];


(* ::Subsection::Closed:: *)
(*InitializeGitLibrary*)


$EvaluationFileName = Replace[$InputFileName, "" :> NotebookFileName[EvaluationNotebook[]]]


$GitLibraryPath := {
	FileNameJoin[{Nest[DirectoryName, $EvaluationFileName, 2], "LibraryResources", $SystemID}]
}


InitializeGitLibrary[] := 
Block[{path, $LibraryPath = Join[$GitLibraryPath, $LibraryPath]},
	path = FindLibrary["gitLink"];
	If[!StringQ[path],
		$GitLibrary=.;
		Message[InitializeGitLibrary::libnotfound];
		$Failed,
		
		$GitLibrary = path;
		$GitCredentialsFile = FileNameJoin[{$HomeDirectory, ".ssh", "id_rsa"}];

		GL`libGitVersion = LibraryFunctionLoad[$GitLibrary, "libGitVersion", {}, {Integer, 1}];
		GL`libGitFeatures = LibraryFunctionLoad[$GitLibrary, "libGitFeatures", LinkObject, LinkObject];

		GL`GitRepoQ = LibraryFunctionLoad[$GitLibrary, "GitRepoQ", LinkObject, LinkObject];
		GL`GitRemoteQ = LibraryFunctionLoad[$GitLibrary, "GitRemoteQ", {Integer, "UTF8String"}, "Boolean"];
		GL`GitBranchQ = LibraryFunctionLoad[$GitLibrary, "GitBranchQ", {Integer, "UTF8String"}, "Boolean"];
		GL`GitCommitQ = LibraryFunctionLoad[$GitLibrary, "GitCommitQ", LinkObject, LinkObject];

		GL`GitProperties = LibraryFunctionLoad[$GitLibrary, "GitProperties", LinkObject, LinkObject];
		GL`GitCommitProperties = LibraryFunctionLoad[$GitLibrary, "GitCommitProperties", LinkObject, LinkObject];
		GL`GitStatus = LibraryFunctionLoad[$GitLibrary, "GitStatus", LinkObject, LinkObject];
		GL`GitSHA = LibraryFunctionLoad[$GitLibrary, "GitSHA", LinkObject, LinkObject];
		GL`GitRange = LibraryFunctionLoad[$GitLibrary, "GitRange", LinkObject, LinkObject];
		GL`GitSignature = LibraryFunctionLoad[$GitLibrary, "GitSignature", LinkObject, LinkObject];
		GL`GitType = LibraryFunctionLoad[$GitLibrary, "GitType", LinkObject, LinkObject];
		GL`ToGitObject = LibraryFunctionLoad[$GitLibrary, "ToGitObject", LinkObject, LinkObject];

		GL`GitClone = LibraryFunctionLoad[$GitLibrary, "GitClone", LinkObject, LinkObject];
		GL`GitFetch = LibraryFunctionLoad[$GitLibrary, "GitFetch", LinkObject, LinkObject];
		GL`GitPush = LibraryFunctionLoad[$GitLibrary, "GitPush", LinkObject, LinkObject];
		GL`GitCherryPick = LibraryFunctionLoad[$GitLibrary, "GitCherryPick", LinkObject, LinkObject];
		GL`GitMerge = LibraryFunctionLoad[$GitLibrary, "GitMerge", LinkObject, LinkObject];
		GL`GitCherryPickCommit = LibraryFunctionLoad[$GitLibrary, "GitCherryPickCommit", LinkObject, LinkObject];
		GL`GitCreateBranch = LibraryFunctionLoad[$GitLibrary, "GitCreateBranch", LinkObject, LinkObject];
		GL`GitDeleteBranch = LibraryFunctionLoad[$GitLibrary, "GitDeleteBranch", LinkObject, LinkObject];
		GL`GitMoveBranch = LibraryFunctionLoad[$GitLibrary, "GitMoveBranch", LinkObject, LinkObject];
		GL`GitUpstreamBranch = LibraryFunctionLoad[$GitLibrary, "GitUpstreamBranch", LinkObject, LinkObject];
		GL`GitSetUpstreamBranch = LibraryFunctionLoad[$GitLibrary, "GitSetUpstreamBranch", LinkObject, LinkObject];
		GL`GitAddRemote = LibraryFunctionLoad[$GitLibrary, "GitAddRemote", LinkObject, LinkObject];
		GL`GitDeleteRemote = LibraryFunctionLoad[$GitLibrary, "GitDeleteRemote", LinkObject, LinkObject];
		GL`GitSetHead = LibraryFunctionLoad[$GitLibrary, "GitSetHead", LinkObject, LinkObject];
		GL`GitCheckoutHead = LibraryFunctionLoad[$GitLibrary, "GitCheckoutHead", LinkObject, LinkObject];

		GL`GitTreeExpand = LibraryFunctionLoad[$GitLibrary, "GitTreeExpand", LinkObject, LinkObject];

		GL`AssignToManagedRepoInstance = LibraryFunctionLoad[$GitLibrary, "assignToManagedRepoInstance", LinkObject, LinkObject];
		"Initialization complete";
	]
]


(* ::Subsection::Closed:: *)
(*Utilities*)


assignToManagedRepoInstance[path_String, GitRepo[id_Integer]] :=
	If[GL`AssignToManagedRepoInstance[path, id] === "", $Failed, GitRepo[id]]


cleanRepo[repo: GitRepo[_Integer]] :=
	DeleteFile[ FileNames["*.orig", GitProperties[repo, "WorkingDirectory"], Infinity] ]


(*
handleConflictedNotebook attempts to clean up bad notebook merges.

If there are conflict marks in the body of the Notebook[] expression, it
can't be automatically cleaned up. Return "Uncleanable".

If there are conflict marks outside the body of the Notebook, clear out 
the comment marks and save the cleaned notebook file to a new file. Return
"Cleaned" \[Rule] "new file name".
*)

handleConflictedNotebook[nbfile_String] := 
Module[{lines, begin, end, conflictsequence, state, newfile},
	begin = "(* Beginning of Notebook Content *)";
	end = "(* End of Notebook Content *)";
	conflictsequence = Sequence @@ {"<<<<<<< ", "=======", ">>>>>>> "};

	lines = FindList[nbfile, {begin, end, conflictsequence}];
	state = Switch[lines,
		{begin, end},
			"Clean",
		{__, begin, end} | {begin, end, __} | {__, begin, end, __},
			"Cleanable",
		{___, begin, __, end, ___} | {__},
			"Uncleanable",
		{},
			"Clean(NoCache)",
		_,
			"--UnknownState--"
	];
	If[state === "Cleanable",
		lines = ReadList[nbfile, Record, RecordSeparators -> {"\r\n", "\n", "\r"}, NullRecords -> True];
		lines = Replace[lines, {___, begin, content__, end, ___} :> {content}];
		newfile = FileNameJoin[MapAt["CLEANED-" <> # &, FileNameSplit[nbfile], -1]];
		"Cleaned" -> Export[newfile, ToExpression @ StringJoin[Riffle[lines, "\n"]], "NB"],
		state		
	]
]


isHead[repo_GitRepo, ref_String] := (
	ref === "HEAD" ||
	ref === GitProperties[repo]["HEAD"] ||
	StringJoin["refs/heads/", ref] === GitProperties[repo]["HEAD"]
)


(* ::Subsection::Closed:: *)
(*Introspection*)


$GitLibraryInformation := 
Association[{
	"Version" -> Replace[GL`libGitVersion[], {a_List :> StringJoin[Riffle[ToString /@ a, "."]], _ -> None}],
	"Features" -> Replace[GL`libGitFeatures[], {a_List :> a, _ -> None}],
	"Location" -> Replace[$GitLibrary, {a_String :> a, _ -> Missing["NotFound"]}],
	"Date" -> Replace[$GitLibrary, {a_String :> FileDate[a], _ -> None}]
}]


(* ::Subsection::Closed:: *)
(*Q functions*)


GitRepoQ[path_] := With[{abspath = AbsoluteFileName[path]}, StringQ[abspath] && TrueQ[GL`GitRepoQ[abspath]]];


GitRemoteQ[GitRepo[id_Integer], remote_] := StringQ[remote] && TrueQ[GL`GitRemoteQ[id, remote]];
GitRemoteQ[__] := $Failed


GitBranchQ[GitRepo[id_Integer], branch_] := StringQ[branch] && TrueQ[GL`GitBranchQ[id, branch]];
GitBranchQ[__] := $Failed


GitCommitQ[GitRepo[id_Integer], branch_] := StringQ[branch] && TrueQ[GL`GitCommitQ[id, branch]];
GitCommitQ[GitObject[sha_String, GitRepo[id_Integer]]] := TrueQ[GL`GitCommitQ[id, sha]];
GitCommitQ[__] := $Failed


(* ::Subsection::Closed:: *)
(*Query functions*)


GitProperties[GitRepo[id_Integer]] := GL`GitProperties[id];

GitProperties[repo: GitRepo[_Integer], All] := GitProperties[repo];
GitProperties[repo: GitRepo[_Integer], "Properties"] := Keys[GitProperties[repo]];
GitProperties[repo: GitRepo[_Integer], prop: (_String | {___String})] := Lookup[GitProperties[repo], prop];

GitProperties[GitObject[sha_String, GitRepo[id_Integer]]?(GitType[#]==="Commit"&)] := GL`GitCommitProperties[id, sha];
GitProperties[GitObject[sha_String, GitRepo[id_Integer]]] := <||>; (* fallthrough for unimplemented properties *)

GitProperties[obj_GitObject, All] := GitProperties[obj];
GitProperties[obj_GitObject, "Properties"] := Keys[GitProperties[obj]];
GitProperties[obj_GitObject, prop: (_String | {___String})] := Lookup[GitProperties[obj], prop];


GitCommitProperties[GitRepo[id_Integer], commit_String] := GL`GitCommitProperties[id, commit];

GitCommitProperties[repo: GitRepo[_Integer], commit_String, All] := GitCommitProperties[repo, commit];
GitCommitProperties[repo: GitRepo[_Integer], commit_String, "Properties"] := Keys[GitCommitProperties[repo, commit]];
GitCommitProperties[repo: GitRepo[_Integer], commit_String, prop: (_String | {___String})] := Lookup[GitCommitProperties[repo, commit], prop];


GitStatus[GitRepo[id_Integer]] := GL`GitStatus[id];

GitStatus[repo: GitRepo[_Integer], All] := GitStatus[repo];
GitStatus[repo: GitRepo[_Integer], "Properties"] := Keys[GitStatus[repo]];
GitStatus[repo: GitRepo[_Integer], prop: (_String | {___String})] := Lookup[GitStatus[repo], prop];


GitSHA[GitRepo[id_Integer], spec_] := GL`GitSHA[id, spec];
GitSHA[GitObject[sha_, _GitRepository]] := sha;


GitRange[GitRepo[id_Integer], spec: ((_String | HoldPattern[Not[_String]])..)] := GL`GitRange[id, spec];


GitSignature[] := GL`GitSignature[];
GitSignature[GitRepo[id_Integer]] := GL`GitSignature[id];
GitSignature[GitRepo[id_Integer], ref_String] := GL`GitSignature[id, ref];


GitType[GitObject[sha_String, GitRepo[id_]]] := GL`GitType[id, sha];
GitType[_] := None;


ToGitObject[ref_String, GitRepo[id_]] := GL`ToGitObject[id, ref];
ToGitObject[_] := $Failed;


(* ::Subsection::Closed:: *)
(*Git commands*)


GitOpen[path_String]:=
	With[{abspath = AbsoluteFileName[path]},
		If[StringQ[abspath] && GitRepoQ[abspath],
			assignToManagedRepoInstance[abspath, CreateManagedLibraryExpression["gitRepo", GitRepo]],
			$Failed] ];


errorValueQ[str_String] := (str =!= "success")


Options[GitClone] = {"Bare" -> False};

GitClone[uri_String, opts:OptionsPattern[]] :=
	Module[{dirName = Last[StringSplit[uri, "/"|"\\"]]},
		dirName = StringReplace[dirName, c__~~".git"~~EndOfString :> c];
		GitClone[uri, FileNameJoin[{Directory[], dirName}], opts]
	]
GitClone[uri_String, localPath_String, OptionsPattern[]] :=
	GL`GitClone[uri, localPath, $GitCredentialsFile, TrueQ @ OptionValue["Bare"]];


Options[GitFetch] = {"Prune" -> False};

GitFetch[GitRepo[id_Integer], remote_String, OptionsPattern[]] :=
	GL`GitFetch[id, remote, $GitCredentialsFile, TrueQ @ OptionValue["Prune"]];


Options[GitPush] = {};

GitPush[GitRepo[id_Integer], remote_String, branch_String, OptionsPattern[]] :=
	GL`GitPush[id, remote, $GitCredentialsFile, branch];


Options[GitCherryPick] = {};

(* flaky...returns true false with a changed index...decide what to do here *)
GitCherryPick[GitRepo[id_Integer], commit_String, branch_String, OptionsPattern[]] :=
	GL`GitCherryPick[id, commit];

(* much better...returns the SHA of the new commit or $Failed *)
GitCherryPick[GitRepo[id_Integer], fromCommit_String, toCommit_String, reference_String] :=
	GL`GitCherryPickCommit[id, fromCommit, toCommit, reference];
GitCherryPick[___] := $Failed;


Options[GitMerge] = {
	"CommitMessage"->None,
	"ConflictFunctions"-><||>,
	"FinalFunctions"-><||>,
	"ProgressMonitor"->None,
	"AllowCommit"->True,
	"AllowFastForward"->True,
	"AllowIndexChanges"->True};

(* flaky...returns true false with a changed index...decide what to do here *)
GitMerge[repo:GitRepo[id_Integer], source_List, dest:(None|_String):"HEAD", OptionsPattern[]] :=
	Catch[Module[{result, oldCommit},
		If[dest === "HEAD" && TrueQ[GitProperties[repo]["DetachedHeadQ"]],
			Message[GitMerge::nobranch]; Throw[$Failed, GitMerge]];
		If[!MatchQ[dest, None|"HEAD"] && !GitBranchQ[repo, dest],
			Message[GitMerge::nobranch]; Throw[$Failed, GitMerge]];
		If[dest =!= None, oldCommit = ToGitObject[dest, mergeRepo]];
		result = GL`GitMerge[id, source, dest,
			OptionValue["CommitMessage"],
			{OptionValue["ConflictFunctions"], OptionValue["FinalFunctions"], OptionValue["ProgressMonitor"]},
			OptionValue["AllowCommit"],
			OptionValue["AllowFastForward"],
			OptionValue["AllowIndexChanges"]
		];
		If[dest === None, Throw[result, GitMerge]];
		If[!GitMoveBranch[If[dest === "HEAD", GitProperties[repo]["HEAD"], dest], result, oldCommit],
			Message[GitMerge::branchnotmoved, dest]; Throw[$Failed, GitMerge]];
		If[isHead[repo, dest], GitCheckout[repo, "HEAD", "CheckoutStrategy"->{"Force"}]];
		result], GitMerge];


Options[GitCreateBranch] = {"Force"->False};

(* returns True/False, sets the branch on the given commit *)
GitCreateBranch[GitRepo[id_Integer], branch_String, commit_String:"HEAD", OptionsPattern[]] :=
	GL`GitCreateBranch[id, branch, commit, TrueQ[OptionValue["Force"]]];


Options[GitDeleteBranch] = {"Force"->False};

(* returns Null/$Failed, deletes the given branch *)
GitDeleteBranch[GitRepo[id_Integer], branch_String, OptionsPattern[]] :=
	GL`GitDeleteBranch[id, branch, TrueQ[OptionValue["Force"]]];


Options[GitMoveBranch] = {};

(* returns True/False, sets the branch on the given commit *)
GitMoveBranch[branch_String, GitObject[dest_String, GitRepo[id_Integer]], source_:None, OptionsPattern[]] :=
	GL`GitMoveBranch[
		id,
		StringReplace[branch, StartOfString~~"refs/heads/"~~val__:>val],
		dest, source
	];


Options[GitUpstreamBranch] = {};

(* returns the upstream branch for the given branch, or None if there is none, or $Failed *)
GitUpstreamBranch[GitRepo[id_Integer], branch_String, OptionsPattern[]] :=
	GL`GitUpstreamBranch[id, branch];


Options[GitSetUpstreamBranch] = {};

(* returns True/False, sets the branch on the given commit *)
GitSetUpstreamBranch[GitRepo[id_Integer], branch_String, upstreamBranch_String, OptionsPattern[]] :=
	GL`GitSetUpstreamBranch[id, branch, upstreamBranch];


Options[GitAddRemote] = {};

(* returns an Association or $Failed, creates a remote *)
GitAddRemote[GitRepo[id_Integer], remote_String, uri_String] :=
	GL`GitAddRemote[id, remote, uri];


Options[GitDeleteRemote] = {};

(* returns an Association or $Failed, deletes a remote *)
GitDeleteRemote[GitRepo[id_Integer], remote_String, OptionsPattern[]] :=
	GL`GitDeleteRemote[id, remote];


Options[GitCreateTrackingBranch] = {};

(* returns an Association or $Failed, deletes a remote *)
GitCreateTrackingBranch[repo_GitRepo, refName_String, remoteRef_String:"", OptionsPattern[]] :=
	Catch[Module[{remote,upstreamRef = remoteRef},
		If[upstreamRef==="",
			remote = "origin"; (* fix me *)
			upstreamRef = remote<>"/"<>refName;
			If[FreeQ[GitProperties[repo]["RemoteBranches"], upstreamRef],
				Message[GitCreateTrackingBranch::noBranchFound];
				Throw[$Failed, "GitCreateTrackingBranch"]
			];
		];
		GitCreateBranch[repo, refName, upstreamRef];
		GitSetUpstreamBranch[repo, refName, upstreamRef];
		(* hmm...what should this return? *)
	], "GitCreateTrackingBranch"]


Options[GitCheckout] = {"CheckoutStrategy"->{"Safe"}, "Notifications"-><||>};

(* returns an Association or $Failed, deletes a remote *)
GitCheckout[GitRepo[id_Integer], refName_String, OptionsPattern[]] :=
	Module[{result},
		If[!GitCommitQ[GitRepo[id], refName] && GitCreateTrackingBranch[GitRepo[id], refName]===$Failed,

			Message[GitCheckout::refNotFound]; $Failed,
			result = If[refName === "HEAD", ToGitObject[repo, refName], GL`GitSetHead[id, refName]];

			If[result =!= $Failed, GL`GitCheckoutHead[id, OptionValue["CheckoutStrategy"], OptionValue["Notifications"]]];
			result
		]
	]


(* ::Subsection::Closed:: *)
(*Bare metal Git operations*)


Options[GitTreeExpand] = {};

(* returns a list of GitObjects *)
GitTreeExpand[obj_GitObject, depth_:1] := 
	Switch[GitType[obj],
		"Commit", GL`GitTreeExpand[GitProperties[obj]["Tree"], depth],
		"Tree", GL`GitTreeExpand[obj, depth],
		_, obj];
GitTreeExpand[objs:{___GitObject}, depth_:1] :=
	Map[GitTreeExpand[#, depth]&, objs]


(* ::Subsection::Closed:: *)
(*Typeset rules*)


giticon = Graphics[{EdgeForm[Gray],
	Gray, Thickness[0.1], Line[{{0,0},{5,0}}], Line[{{0,0},{5,-3}}],
	LightGray, Disk[{0,0},1], Disk[{5,0},1], Green, Disk[{5,-3},1]}, ImageSize -> 15];


BoxForm`MakeConditionalTextFormattingRule[GitRepo];

GitRepo /: MakeBoxes[GitRepo[id_Integer], fmt_] :=
	With[{
		icon = ToBoxes[giticon],
		name = Replace[GitProperties[GitRepo[id], "WorkingDirectory"], {a_String :> ToBoxes[a, fmt], _ :> MakeBoxes[id, fmt]}],
		tooltip = ToString[GitRepo[id], InputForm]},

		TemplateBox[{MakeBoxes[id, fmt]}, "GitRepo",
				DisplayFunction -> (
					TooltipBox[PanelBox[GridBox[{{icon, name}}, BaselinePosition -> {1,2}],
						FrameMargins -> 5, BaselinePosition -> Baseline], tooltip]&)]
	]


GitObject /: MakeBoxes[obj:GitObject[sha_String, repo: GitRepo[_Integer]], fmt_] :=
Block[{shortsha, dir, type, bg, display},
	(*
		String and GitRepo are typically inert, so perhaps the evaluation leaks 
		here aren't that serious.
	*)
	shortsha = StringTake[sha, Min[8, StringLength[sha]]];
	dir = GitProperties[repo, "WorkingDirectory"];
	type = Replace[GitType[obj], Except[_String] :> "UnknownType"];

	bg = Switch[type,
		"Commit", Lighter[Green, 0.9],
		"Tree" | "Blob" | "AnnotatedTag", Lighter[Purple, 0.9],
		"OffsetDelta" | "ObjectDelta", Lighter[Orange, 0.9],
		_, Lighter[Red, 0.9]
	];

	display = Tooltip[
		Framed[
			Row[{Style[type, Italic], ": ", shortsha, "\[Ellipsis]"}],
			Background -> bg,
			BaselinePosition -> Baseline,
			BaseStyle -> "Panel",
			FrameMargins -> {{5,5},{3,3}},
			FrameStyle -> GrayLevel[0.8],
			RoundingRadius -> 5
		],
		Row[{type, " in ", dir, ": ", Style[sha, Bold]}]
	];
	
	(* should probably recast this as a TemplateBox eventually *)
	With[{boxes = ToBoxes[display, fmt]},
		InterpretationBox[boxes, obj]
	]
]


(* ::Subsection::Closed:: *)
(*Palette work*)


(*
Ultimate goals:

1. Merging pull requests in the right way (via cherry picking and rebase) rather than 
via merge commits (which (a) leave a tangled history, and (b) use a horrible message for the
merge commit).

2. Automatic handling of / knowledge of WRI-specific collections of repos. Eg: the collection
of repos that are needed to build the front end. You shouldn't need to go to a twiki to find
that out.

3. Automatic merging / building of an executable from a manifest file which lists multiple
branches for each repo, with some common sense about merge failures. (Eg, when merging
branches a, b, and c into repo x, first merge a, then b, then c. If there were merge failures
for any particular branch, back out that branch's merge and continue with the next one.)
*)


(* 
GitRepoList returns a list whose elements are any of:
Menu[label, list of elements]
MenuItem[path]
MenuItem[label, path, opts]
path
*)

GitRepoList[a_List] := (CurrentValue[$FrontEnd, {"PrivateFrontEndOptions", "InterfaceSettings", "GitLink", "RepoList"}] = a);

GitRepoList[] := CurrentValue[$FrontEnd, {"PrivateFrontEndOptions", "InterfaceSettings", "GitLink", "RepoList"}, {}]

GitRepoList["Flat"] := Flatten[GitRepoList[] //. {Menu[_, a_List] :> a, MenuItem[path_] :> path, MenuItem[label_, path_, ___] :> path}]


addRepoToViewer[Dynamic[repo_]] := Replace[
	SystemDialogInput["Directory", WindowTitle -> "Select a directory containing a git repository"],
	a_String :> If[GitRepoQ[a],
		(GitRepoList[Append[GitRepoList[], AbsoluteFileName[a]]]; repo = GitOpen[a]),
		(Message[GitOpen::notarepo, a]; repo = None)
	]
]


ManageGitRepoList[] := CreateDocument[ExpressionCell[Defer[CurrentValue[$FrontEnd, {"PrivateFrontEndOptions", "InterfaceSettings", "GitLink", "RepoList"}] = #], "Input"]]& @ GitRepoList[]


viewerToolbar[Dynamic[repo_], Dynamic[branch_]] :=
	Grid[{Button[#, Enabled -> False]& /@ {"Fetch", "Pull", "Push", "Branch", "Merge", "Commit", "Reveal", "Help"}}, ItemSize -> Full]


chooseRepositoryMenu[Dynamic[repo_]] := 
	ActionMenu["Repositories",
		Flatten[{
			(Row[{FileNameTake[#], Style[" \[LongDash] " <> FileNameDrop[#], FontColor -> Gray]}] :> (repo = GitOpen[#]))& /@ GitRepoList["Flat"],
			If[GitRepoList["Flat"] === {}, {}, Delimiter],
			"Browse\[Ellipsis]" :> addRepoToViewer[Dynamic[repo]],
			Delimiter,
			"Manage Repository List\[Ellipsis]" :> ManageGitRepoList[]
		}],
		Method->"Queued"
	]


viewerSummaryColumn[Dynamic[repo_], Dynamic[branch_]] := chooseRepositoryMenu[Dynamic[repo]] /; repo === None

viewerSummaryColumn[Dynamic[repo_], Dynamic[branch_]] :=
	Column[Flatten[{
		chooseRepositoryMenu[Dynamic[repo]],
		Grid[{{
			Style[GitProperties[repo, "WorkingDirectory"], Larger],
			Button[
				Dynamic[RawBoxes @ FEPrivate`FrontEndResource["FEBitmaps", "CircleXIcon"]],
				repo = None,
				Appearance -> None]
		}}],
		Column[{
			Style["Local Branches:", Bold],
			Replace[GitProperties[repo, "LocalBranches"], { branches: {__} :> branchHierarchy[Dynamic[repo], Dynamic[branch], branches], _ :> "-none-"}]
		}],
		Column[{
			Style["Remote Branches:", Bold],
			Replace[GitProperties[repo, "RemoteBranches"], { branches: {__} :> branchHierarchy[Dynamic[repo], Dynamic[branch], branches], _ :> "-none-"}]
		}],

		Grid[Join[
				{{Style["Other Properties:", Bold], SpanFromLeft}},
				DeleteCases[List @@@ Normal[GitProperties[repo]], {("LocalBranches" | "RemoteBranches" | "Remotes"), _}],
				{{"Remotes", Replace[GitProperties[repo, "Remotes"], { remotes_Association :> Tooltip[Keys[remotes], remotes], _ -> {} }]}}
			],
			Alignment -> Left
		]
	}], Spacings -> 2, Dividers -> Center, FrameStyle -> LightGray, ItemSize -> Full]


branchicon = Graphics[{EdgeForm[Gray],
	Gray, Thickness[0.1], Line[{{0,0},{5,0}}], Line[{{0,0},{5,-3}}],
	LightGray, Disk[{0,0},1], Disk[{5,0},1], Green, Disk[{5,-3},1]}, ImageSize -> 15];

branchopenericon = Dynamic[RawBoxes[FEPrivate`ImportImage[FrontEnd`ToFileName[{"Popups", "CodeCompletion"}, "MenuItemDirectoryTiny.png"]]]];

formatBranch[Dynamic[repo_], Dynamic[branch_], {prefix___, name_}] := 
With[{branchname = FileNameJoin[{prefix, name}]},
	Button[
		Row[{branchicon, " ", Tooltip[name, branchname]}, BaseStyle -> Dynamic[If[CurrentValue["MouseOver"] || branch === branchname, Bold, {}]]],
		branch = branchname,
		Appearance -> None,
		BaseStyle -> {},
		DefaultBaseStyle -> {}
	]
]

formatBranchOpener[Dynamic[repo_], Dynamic[branch_], {above___, here_}, allbranches_] := 
	OpenerView[{
		Row[{branchopenericon, " ", here}],
		Column[
			Module[{branches, subbranches},
				branches = Cases[allbranches, {above, here, name_} :> {above, here, name}];
				subbranches = Cases[allbranches, {above, here, next_, __} :> {above, here, next}];
				Join[
					formatBranch[Dynamic[repo], Dynamic[branch], #]& /@ Union[branches],
					formatBranchOpener[Dynamic[repo], Dynamic[branch], #, allbranches]& /@ Union[subbranches]
				]
			],
			BaselinePosition -> {1,1},
			ItemSize -> Full
		]
	}]

branchHierarchy[Dynamic[repo_], Dynamic[branch_], prop_String] := branchHierarchy[Dynamic[repo], Dynamic[branch], GitProperties[repo, prop]]

branchHierarchy[Dynamic[repo_], Dynamic[branch_], branchList: {___String}] := 
Module[{allbranches = StringSplit[branchList, "/"], branches, subbranches},
	branches = Cases[allbranches, {_}];
	subbranches = Cases[allbranches, {base_, __} :> {base}];
	Column[
		Join[
			formatBranch[Dynamic[repo], Dynamic[branch], #]& /@ Union[branches],
			formatBranchOpener[Dynamic[repo], Dynamic[branch], #, allbranches]& /@ Union[subbranches]
		],
		BaselinePosition -> {1,1},
		ItemSize -> Full
	]
]


viewerDetailView[Dynamic[repo_], Dynamic[branch_], Dynamic[tab_]] :=
	If[repo === None,
		Style["No repository selected", LightGray],
		TabView[
			{
				{"Status", "Status" -> repoStatusGrid[repo]},
				{"Branch", branch -> branchHistoryGrid[repo, branch, GitRange[repo, branch, Not["origin/master"]]]}
			},
		Dynamic[tab],
		ImageSize -> Scaled[1]]
	]


repoStatusGrid[repo_] := 
Grid[
	Join[
		{{Style["Status:", Bold], SpanFromLeft}},
		List @@@ Normal[GitStatus[repo]]
	],
	Alignment -> Left
]


branchHistoryGrid[repo_, branch_, commits: {__}] :=
Grid[
	{
		Tooltip[DateString[#AuthorTime, "DateShort"], DateString[#AuthorTime, "DateTime"]],
		Tooltip[#AuthorName, #AuthorEmail],
		If[#Summary === #Message, #Summary, Tooltip[#Summary, #Message]],
		Tooltip[StringTake[#SHA, 8], Dataset[#]]
	}& /@ (GitCommitProperties[repo, #]& /@ commits),
	Alignment -> Left,
	BaseStyle -> {"TextStyling", LinebreakAdjustments -> {1., 10, 1, 0, 1}},
	(*Spacings \[Rule] {1,1},*)
	Dividers -> {Center, Center},
	FrameStyle -> LightGray
]

branchHistoryGrid[repo_, branch_, commits: {}] := Row[{"No commits found in ", Defer[GitRange[repo, branch, Not["origin/master"]]]}]


RepoViewer[] := 
DynamicModule[{repo = None, branch = "origin/HEAD", tab = "Status"},
	Dynamic[
		Grid[{
			{
				Pane[viewerToolbar[Dynamic[repo], Dynamic[branch]], ImageMargins -> 10],
				SpanFromLeft
			},
			{
				Pane[viewerSummaryColumn[Dynamic[repo], Dynamic[branch]], ImageMargins -> 10, ImageSize -> {{250},{Automatic}}],
				Dynamic[
					Item[Pane[viewerDetailView[Dynamic[repo], Dynamic[branch], Dynamic[tab]], ImageMargins -> 10], Background -> White, ItemSize -> Fit],
					TrackedSymbols :> {repo, branch}
				]
			}},
			Alignment -> {Left, Top},
			Background -> GrayLevel[0.95],
			Dividers -> {Center, Center},
			FrameStyle -> LightGray
		],
		SynchronousUpdating -> False,
		TrackedSymbols :> {repo}
	]
]


ShowRepoViewer[] := 
CreatePalette[
	RepoViewer[],
	Saveable -> False,
	WindowSize -> {650,500},
	WindowElements -> {"StatusArea", "HorizontalScrollBar", "VerticalScrollBar"},
	WindowFrameElements -> {"CloseBox", "ZoomBox", "MinimizeBox", "ResizeArea"},
	WindowTitle -> "Git"
]


(* ::Input:: *)
(*NotebookClose[nb];*)
(*nb = ShowRepoViewer[];*)


(* ::Subsection::Closed:: *)
(*Initialize the library*)


InitializeGitLibrary[]


(* ::Subsection::Closed:: *)
(*Package footer*)


End[];
EndPackage[];


(* ::Section:: *)
(*Tests*)


(* ::Subsection::Closed:: *)
(*Basic tests*)


(* ::Input:: *)
(*$GitLibraryInformation*)


(* ::Input:: *)
(*{GitRepoQ["/Users/jfultz/wolfram/fe/Fonts"],GitRepoQ["/Users/jfultz/wolfram/fe"],GitRepoQ["/files/git/fe/Fonts"]}*)


(* ::Input:: *)
(*repo=GitOpen["/Users/jfultz/test_repo"]*)


(* ::Input:: *)
(*GitProperties[repo]*)


(* ::Input:: *)
(*GitRange[repo,"feature/conflict"]*)


(* ::Input:: *)
(*GitCommitProperties[repo,"master"]*)


(* ::Input:: *)
(*GitStatus[repo]*)


(* ::Input:: *)
(*GitSHA[repo,#]&/@{"master","master@{1}","ce36c95",Not["master"],"bogus","1234abcd",foo[bar],1/3}*)


(* ::Input:: *)
(*GitCommitQ[repo,#]&/@{"master","master@{1}","ce36c95",Not["master"],"bogus","1234abcd",foo[bar],1/3}*)


(* ::Input:: *)
(*{GitRemoteQ[repo,"origin"],GitRemoteQ[repo,"foo"]}*)


(* ::Input:: *)
(*{GitBranchQ[repo,"master"],GitBranchQ[repo,"foo"]}*)


(* ::Subsection::Closed:: *)
(*Fetch/Push/Branch tests*)


(* ::Input:: *)
(*repo2=GitOpen["/Users/jfultz/wolfram/git/Test2"]*)


(* ::Input:: *)
(*GitRemoteQ[repo2,"origin"]*)


(* ::Input:: *)
(*GitProperties[repo2]*)


(* ::Input:: *)
(*GitFetch[repo2,"origin"]*)


(* ::Input:: *)
(*GitPush[repo2,"origin","master"]*)


(* ::Input:: *)
(*GitCommitQ[repo2,"origin/master"]*)


(* ::Input:: *)
(*GitCreateBranch[repo2, "master", "origin/master"]*)


(* ::Input:: *)
(*GitCreateBranch[repo2, "master", "origin/master","Force"->True]*)


(* ::Input:: *)
(*GitSHA[repo2,"origin/master"]*)


(* ::Subsection::Closed:: *)
(*Git clone*)


(* ::Input:: *)
(*SetDirectory[$TemporaryDirectory];*)
(*cloneRepo1=GitClone["ssh://git@stash.wolfram.com:7999/misc/test_repo.git"]*)
(*ResetDirectory[];*)
(*GitRepoQ[FileNameJoin[{$TemporaryDirectory,"test_repo"}]]*)
(*GitProperties[cloneRepo1]["BareQ"]*)


(* ::Input:: *)
(*cloneRepo2 = GitClone[FileNameJoin[{$TemporaryDirectory,"test_repo"}],FileNameJoin[{$TemporaryDirectory,"test_repo2"}], "Bare"->True]*)
(*GitRepoQ[FileNameJoin[{$TemporaryDirectory,"test_repo2"}]]*)
(*GitProperties[cloneRepo2]["BareQ"]*)


(* ::Input:: *)
(*DeleteDirectory[FileNameJoin[{$TemporaryDirectory,"test_repo"}],DeleteContents->True];*)
(*DeleteDirectory[FileNameJoin[{$TemporaryDirectory,"test_repo2"}],DeleteContents->True];*)


(* ::Subsection::Closed:: *)
(*Git remote*)


(* ::Input:: *)
(*SetDirectory[$TemporaryDirectory];*)
(*cloneRepo1=GitClone["ssh://git@stash.wolfram.com:7999/misc/test_repo.git"]*)
(*ResetDirectory[];*)
(*GitProperties[cloneRepo1]["Remotes"]*)


(* ::Input:: *)
(*GitAddRemote[cloneRepo1,"new","ssh://git@stash.wolfram.com:7999/misc/test_repo.git"]*)
(*GitProperties[cloneRepo1]["Remotes"]*)
(*GitFetch[cloneRepo1,"new"]*)
(*GitProperties[cloneRepo1]["RemoteBranches"]*)
(*GitDeleteRemote[cloneRepo1,"new"]*)
(*GitProperties[cloneRepo1]["Remotes"]*)
(*GitProperties[cloneRepo1]["RemoteBranches"]*)


(* ::Input:: *)
(*DeleteDirectory[FileNameJoin[{$TemporaryDirectory,"test_repo"}],DeleteContents->True];*)


(* ::Subsection::Closed:: *)
(*Git merge*)


(* ::Input:: *)
(*Quiet@DeleteDirectory[FileNameJoin[{$TemporaryDirectory,"testrepo"}],DeleteContents->True];*)
(*SetDirectory[$TemporaryDirectory];*)
(*mergeRepo=GitClone["ssh://git@stash.wolfram.com:7999/~jfultz/testrepo.git"];*)
(*ResetDirectory[];*)


(* ::Input:: *)
(*commit=GitMerge[mergeRepo, {"origin/mergeA", "origin/mergeB"}, "master","CommitMessage"->"Merge mergeA and mergeB into HEAD"]*)


(* ::Input:: *)
(*Sort[GitProperties[commit]["Parents"]]===Sort[ToGitObject[#,mergeRepo]&/@{"origin/mergeA","origin/mergeB","HEAD@{1}"}]*)


(* ::Input:: *)
(*GitProperties[ GitMerge[mergeRepo, {"origin/mergeA", "origin/mergeB"}, None]]["Parents"]===Sort[ToGitObject[#,mergeRepo]&/@{"origin/mergeA","origin/mergeB"}]*)


(* ::Input:: *)
(*GitMerge[mergeRepo, {"origin/mergeA", "origin/mergeB"}, "AllowCommit"->False]*)


(* ::Input:: *)
(*GitMerge[mergeRepo, {"origin/mergeA", "origin/mergeB"}, "AllowCommit"->False,"AllowIndexChanges"->False]*)


(* ::Subsection::Closed:: *)
(*Git checkout*)


(* ::Input:: *)
(*Quiet@DeleteDirectory[FileNameJoin[{$TemporaryDirectory,"testrepo"}],DeleteContents->True];SetDirectory[$TemporaryDirectory];*)
(*repo=GitClone["ssh://git@stash.wolfram.com:7999/~jfultz/testrepo.git"];*)
(*ResetDirectory[];*)


(* ::Input:: *)
(*GitProperties[repo]["HEAD"]*)
(*GitProperties[repo]["RemoteBranches"]*)


(* ::Input:: *)
(*GitCheckout[repo,"merge1"]*)
(*GitProperties[repo]["HEAD"]*)


(* ::Input:: *)
(*GitCheckout[repo,GitSHA[repo,"origin/merge1"]]*)
(*GitProperties[repo]["HEAD"]*)


(* ::Input:: *)
(*GitCheckout[repo,"origin/merge1"]*)
(*GitProperties[repo]["HEAD"]*)


(* ::Input:: *)
(*GitCheckout[repo,"merge2","CheckoutStrategy"->{"Force"}]*)
(*GitProperties[repo]["HEAD"]*)


(* ::Input:: *)
(*DeleteDirectory[FileNameJoin[{$TemporaryDirectory,"testrepo"}],DeleteContents->True]*)


(* ::Subsection::Closed:: *)
(*Git signature*)


(* ::Input:: *)
(*GitSignature[]*)


(* ::Input:: *)
(*GitSignature[GitOpen["c:\\wolfram\\fe\\FrontEnd"]]*)


(* ::Input:: *)
(*GitSignature[GitOpen["c:\\wolfram\\fe\\FrontEnd"],"master"]*)


(* ::Subsection::Closed:: *)
(*Git trees*)


(* ::Input:: *)
(*Quiet@DeleteDirectory[FileNameJoin[{$TemporaryDirectory,"testrepo"}],DeleteContents->True];SetDirectory[$TemporaryDirectory];*)
(*repo=GitClone["ssh://git@stash.wolfram.com:7999/~jfultz/testrepo.git"];*)
(*ResetDirectory[];*)


(* ::Input:: *)
(*GitTreeExpand[GitProperties[ToGitObject["master", repo]]["Tree"]]*)


(* ::Input:: *)
(*GitTreeExpand[GitProperties[ToGitObject["master", repo]]["Tree"]]===GitTreeExpand[ToGitObject["master",repo]]*)


(* ::Subsection::Closed:: *)
(*Lou tests*)


(* ::Input:: *)
(*repo = GitOpen["/files/git/fe/Fonts"]*)


(* ::Input:: *)
(*GitRemoteQ[repo, "origin"]*)


(* ::Input:: *)
(*GitStatus[repo]*)


(* ::Input:: *)
(*GitFetch[repo, "origin"]*)


(* ::Subsection::Closed:: *)
(*Cherry-pick tests*)


(* ::Input:: *)
(*ferepo=GitOpen["~/wolfram/fe/FrontEnd"]*)


(* ::Input:: *)
(*GitSHA[ferepo,"origin/bugfix/266779"]*)


(* ::Input:: *)
(*GitCherryPick[ferepo, "origin/bugfix/266779","origin/master","WOLFRAM_STASH_REBASE_HEAD"]*)


(* ::Input:: *)
(*GitCherryPick[ferepo, "origin/bugfix/266779","origin/master","refs/heads/WOLFRAM_STASH_REBASE_HEAD"]*)
