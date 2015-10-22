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
GitStatus;
GitSHA;
GitRange;
GitAheadBehind;
GitSignature;
GitType;
ToGitObject;

GitRepo;
GitRepos;
GitObject;
GitOpen;
GitClose;
GitClone;
GitInit;
GitFetch;
GitCommit;
GitPush;
GitCherryPick;
GitMerge;
GitMergeBase;
GitPull;
GitAdd;
GitReset;
GitResetRepo;
GitCreateBranch;
GitDeleteBranch;
GitMoveBranch;
GitCreateTag;
GitDeleteTag;
GitUpstreamBranch;
GitSetUpstreamBranch;
GitAddRemote;
GitDeleteRemote;
GitCheckoutReference;
GitGraph;

GitExpandTree;
GitWriteTree;
GitReadBlob;
GitWriteBlob;

GitRepoList;
ManageGitRepoList;

ShowRepoViewer;


Begin["`Private`"];


(* ::Subsection::Closed:: *)
(*InitializeGitLibrary*)


$EvaluationFileName = Replace[$InputFileName, "" :> NotebookFileName[EvaluationNotebook[]]]


$GitLibraryPath := {}


(* Load functions from shared library, but noting which functions can have side effect
 * results on the repos, and triggering those functions to flush the cache on
 * GitProperties[_GitRepo] *)
glFunctionLoad[flushCache_?BooleanQ, name_String] := glFunctionLoad[flushCache, name, LinkObject, LinkObject];
glFunctionLoad[True, name_String, argTypes_, resultType_] :=
	With[{func = LibraryFunctionLoad[$GitLibrary, name, argTypes, resultType]},
		Module[{result},
			FlushRepoPropertiesCache[];
			result = func[##];
			FlushRepoPropertiesCache[];
			result
		]&
	];
glFunctionLoad[False, name_String, argTypes_, resultType_] :=
	LibraryFunctionLoad[$GitLibrary, name, argTypes, resultType];

InitializeGitLibrary[] := 
Block[{path, $LibraryPath = Join[$GitLibraryPath, $LibraryPath], libname},
	libname = If[$OperatingSystem === "MacOSX" &&
				($VersionNumber < 10.4 || $CreationDate < DateObject[{2016, 1, 15}]),
				"gitLink_10_3", "gitLink"];
	path = FindLibrary[libname];
	If[!StringQ[path],
		$GitLibrary=.;
		Message[InitializeGitLibrary::libnotfound];
		$Failed,
		
		$GitLibrary = path;
		$GitCredentialsFile = SelectFirst[FileNameJoin[{$HomeDirectory, ".ssh", #}] & /@ {"id_rsa", "id_dsa"}, FileExistsQ, FileNameJoin[{$HomeDirectory, ".ssh", "id_rsa"}]];

		GL`GitLibraryInformation = glFunctionLoad[False, "GitLibraryInformation", LinkObject, LinkObject];

		GL`GitRepoQ = glFunctionLoad[False, "GitRepoQ"];
		GL`GitRemoteQ = glFunctionLoad[False, "GitRemoteQ"];
		GL`GitBranchQ = glFunctionLoad[False, "GitBranchQ"];
		GL`GitCommitQ = glFunctionLoad[False, "GitCommitQ"];

		GL`GitProperties = glFunctionLoad[False, "GitProperties"];
		GL`GitCommitProperties = glFunctionLoad[False, "GitCommitProperties"];
		GL`GitStatus = glFunctionLoad[False, "GitStatus"];
		GL`GitSHA = glFunctionLoad[False, "GitSHA"];
		GL`GitRange = glFunctionLoad[False, "GitRange"];
		GL`GitAheadBehind = glFunctionLoad[False, "GitAheadBehind"];
		GL`GitSignature = glFunctionLoad[False, "GitSignature"];
		GL`GitType = glFunctionLoad[False, "GitType"];
		GL`ToGitObject = glFunctionLoad[False, "ToGitObject"];

		GL`GitOpen = glFunctionLoad[True, "GitOpen"];
		GL`GitClose = glFunctionLoad[True, "GitClose"];
		GL`GitClone = glFunctionLoad[True, "GitClone"];
		GL`GitInit = glFunctionLoad[True, "GitInit"];
		GL`GitFetch = glFunctionLoad[True, "GitFetch"];
		GL`GitCommit = glFunctionLoad[True, "GitCommit"];
		GL`GitPush = glFunctionLoad[True, "GitPush"];
		GL`GitCherryPick = glFunctionLoad[True, "GitCherryPick"];
		GL`GitMerge = glFunctionLoad[True, "GitMerge"];
		GL`GitMergeBase = glFunctionLoad[True, "GitMergeBase"];
		GL`GitCherryPickCommit = glFunctionLoad[True, "GitCherryPickCommit"];
		GL`GitCreateBranch = glFunctionLoad[True, "GitCreateBranch"];
		GL`GitDeleteBranch = glFunctionLoad[True, "GitDeleteBranch"];
		GL`GitMoveBranch = glFunctionLoad[True, "GitMoveBranch"];
		GL`GitCreateTag = glFunctionLoad[True, "GitCreateTag"];
		GL`GitDeleteTag = glFunctionLoad[True, "GitDeleteTag"];
		GL`GitUpstreamBranch = glFunctionLoad[False, "GitUpstreamBranch"];
		GL`GitSetUpstreamBranch = glFunctionLoad[True, "GitSetUpstreamBranch"];
		GL`GitAddRemote = glFunctionLoad[True, "GitAddRemote"];
		GL`GitDeleteRemote = glFunctionLoad[True, "GitDeleteRemote"];
		GL`GitSetHead = glFunctionLoad[True, "GitSetHead"];
		GL`GitCheckoutHead = glFunctionLoad[True, "GitCheckoutHead"];
		GL`GitCheckoutReference = glFunctionLoad[True, "GitCheckoutReference"];

		GL`GitAddRemovePath = glFunctionLoad[True, "GitAddRemovePath"];

		GL`GitExpandTree = glFunctionLoad[False, "GitExpandTree"];
		GL`GitWriteTree = glFunctionLoad[False, "GitWriteTree"];
		GL`GitDiffTrees = glFunctionLoad[False, "GitDiffTrees"];
		GL`GitIndexTree = glFunctionLoad[False, "GitIndexTree"];
		GL`GitReadBlob = glFunctionLoad[False, "GitReadBlob"];
		GL`GitWriteBlob = glFunctionLoad[False, "GitWriteBlob"];

		"Initialization complete";
	]
]


(* ::Subsection::Closed:: *)
(*Utilities*)


cleanRepo[repo_GitRepo] :=
	DeleteFile[ FileNames["*.orig", GitProperties[repo, "WorkingDirectory"], Infinity] ]


isHeadBranch[repo_GitRepo, ref_String] := 
	With[{headBranch = GitProperties[repo, "HeadBranch"]},
		ref === "HEAD" && StringQ[headBranch] && GitBranchQ[repo, headBranch] ||
		ref === headBranch
	]


(* create tmpBranch at result, check it out, move dest, set HEAD to dest, and clean up *)
relocateHeadBranchIfItExists[repo_GitRepo, result_GitObject, throwTag_] :=
	Module[{headBranch = GitProperties[repo, "HeadBranch"]},
		If[GitBranchQ[repo, headBranch] ,
			If[Quiet@GitCheckoutReference[repo, result] === $Failed,
				Message[throwTag::checkoutconflict]; Throw[$Failed, throwTag]];
			GitMoveBranch[headBranch, result];
			GL`GitSetHead[repo["GitDirectory"], headBranch];
		]
	];


(* ::Subsection::Closed:: *)
(*Introspection*)


$GitLibraryInformation := Join[
<|
	"Location" -> Replace[$GitLibrary, {a_String :> a, _ -> Missing["NotFound"]}],
	"Date" -> Replace[$GitLibrary, {a_String :> FileDate[a], _ -> None}]
|>,
GL`GitLibraryInformation[]]


(* ::Subsection::Closed:: *)
(*Q functions*)


GitRepoQ[path_] := With[{abspath = Quiet@AbsoluteFileName[path]}, StringQ[abspath] && TrueQ[GL`GitRepoQ[abspath]]];


GitRemoteQ[repo_GitRepo, remote_] := StringQ[remote] && TrueQ[GL`GitRemoteQ[repo["GitDirectory"], remote]];
GitRemoteQ[__] := $Failed


GitBranchQ[repo_GitRepo, "HEAD"] := GitBranchQ[repo, GitProperties[repo]["HeadBranch"]];
GitBranchQ[repo_GitRepo, branch_] := StringQ[branch] && TrueQ[GL`GitBranchQ[repo["GitDirectory"], branch]];
GitBranchQ[__] := $Failed


GitCommitQ[repo_GitRepo, branch_] := StringQ[branch] && TrueQ[GL`GitCommitQ[repo["GitDirectory"], branch]];
GitCommitQ[GitObject[sha_String, repo_GitRepo]] := TrueQ[GL`GitCommitQ[repo["GitDirectory"], sha]];
GitCommitQ[__] := $Failed


(* ::Subsection::Closed:: *)
(*Query functions*)


$GitPropertiesCacheTTL = 1.0;

CachedGitProperties[gitDir_String] := Replace[GitPropertiesCache[gitDir], {
	{time_, props_} :> props /; (AbsoluteTime[]-time < $GitPropertiesCacheTTL),
	_ :> Last[GitPropertiesCache[gitDir] = {AbsoluteTime[], GL`GitProperties[gitDir]}] }]

FlushRepoPropertiesCache[gitDir_String] := (Quiet[Unset[GitPropertiesCache[gitDir]]]; gitDir)
FlushRepoPropertiesCache[] := Clear[GitPropertiesCache]

Internal`SetValueNoTrack[GitPropertiesCache, True]


GitRepo[assoc_Association]["GitDirectory"] = assoc["GitDirectory"];
GitRepo[assoc_Association]["BareQ"] = assoc["BareQ"];
GitRepo[assoc_Association]["WorkingDirectory"] = assoc["WorkingDirectory"];
GitRepo[assoc_Association][prop_] = GitProperties[GitRepo[assoc], prop];


GitProperties[repo_GitRepo] := CachedGitProperties[repo["GitDirectory"]];

GitProperties[repo_GitRepo, All] := GitProperties[repo];
GitProperties[repo_GitRepo, "Properties"] := Keys[GitProperties[repo]];
GitProperties[repo_GitRepo, "Panel"] := propertiesPanel[repo];
GitProperties[repo_GitRepo, prop: (_String | {___String})] := Lookup[GitProperties[repo], prop];

GitProperties[GitObject[sha_String, repo_GitRepo]?(MatchQ[GitType[#], "Commit"|"Tag"]&)] := GL`GitCommitProperties[repo["GitDirectory"], sha];
GitProperties[GitObject[sha_String, _GitRepo]] := <||>; (* fallthrough for unimplemented properties *)

GitObject[sha_String, repo_GitRepo]["SHA"] := sha;
GitObject[sha_String, repo_GitRepo]["Repo"] := repo;
GitObject[args__][prop_] := GitProperties[GitObject[args], prop];
GitProperties[obj_GitObject, All] := GitProperties[obj];
GitProperties[obj_GitObject, "Properties"] := Keys[GitProperties[obj]];
GitProperties[obj_GitObject, "Panel"] := propertiesPanel[obj];
GitProperties[obj_GitObject, prop: (_String | {___String})] := Lookup[GitProperties[obj], prop];


GitSHA[repo_GitRepo, spec_] := GL`GitSHA[repo["GitDirectory"], spec];
GitSHA[GitObject[sha_, _GitRepo]] := sha;


$GitRangeMemoizations = <||>;
$GitRangeLengthMemoizations = <||>;
memoizeRangeSpec[var_, func_, spec_List] :=
	Module[{sortedSpec = Sort[spec]},
		If[MatchQ[var[sortedSpec], _Missing], var[sortedSpec] = func @@ sortedSpec, var[sortedSpec]]
	];
SetAttributes[memoizeRangeSpec, HoldAll];
specToGitObject[repo_GitRepo, ref_String] := ToGitObject[repo, ref];
specToGitObject[repo_GitRepo, Not[ref_String]] := Not[ToGitObject[repo, ref]];
specToGitObject[repo_GitRepo, arg_] := arg;

GitRange[repo_GitRepo, spec: ((_GitObject | HoldPattern[Not[_GitObject]])..)] := 
	memoizeRangeSpec[$GitRangeMemoizations, GL`GitRange[repo["GitDirectory"], False, ##]&, {spec}];
GitRangeLength[repo_GitRepo, spec: ((_GitObject | HoldPattern[Not[_GitObject]])..)] :=
	memoizeRangeSpec[$GitRangeLengthMemoizations, GL`GitRange[repo["GitDirectory"], True, ##]&, {spec}];

GitRange[repo_GitRepo, spec: ((_String|_GitObject | HoldPattern[Not[_String|_GitObject]])..)] :=
	GitRange[repo, Sequence @@ (specToGitObject[repo, #]& /@ {spec})];
GitRangeLength[repo_GitRepo, spec: ((_String|_GitObject | HoldPattern[Not[_String|_GitObject]])..)] :=
	GitRangeLength[repo, Sequence @@ (specToGitObject[repo, #]& /@ {spec})];


GitAheadBehind[repo_GitRepo, local_String, upstream_String] :=
	GL`GitAheadBehind[repo["GitDirectory"], local, upstream];
GitAheadBehind[local_GitObject, remote_GitObject] :=
	GitAheadBehind[local["Repo"], local["SHA"], remote["SHA"]];
GitAheadBehind[local_GitObject, remote_String] :=
	GitAheadBehind[local["Repo"], local["SHA"], remote];
GitAheadBehind[local_String, remote_GitObject] :=
	GitAheadBehind[remote["Repo"], local, remote["SHA"]];
GitAheadBehind[repo_GitRepo, local_GitObject, remote_GitObject] :=
	GitAheadBehind[repo, local["SHA"], remote["SHA"]];
GitAheadBehind[repo_GitRepo, local_String, remote_GitObject] :=
	GitAheadBehind[repo, local, remote["SHA"]];
GitAheadBehind[repo_GitRepo, local_GitObject, remote_String] :=
	GitAheadBehind[repo, local["SHA"], remote];


GitSignature[] := GL`GitSignature[];
GitSignature[repo_GitRepo] := GL`GitSignature[repo["GitDirectory"]];
GitSignature[repo_GitRepo, ref_String] := GL`GitSignature[repo["GitDirectory"], ref];


GitType[GitObject[sha_String, repo_GitRepo]] := GL`GitType[repo["GitDirectory"], sha];
GitType[_] := None;


ToGitObject[repo_GitRepo, ref_String] := GL`ToGitObject[repo["GitDirectory"], ref];
ToGitObject[repo_GitRepo, obj:GitObject[_String, repo_GitRepo]] := obj;
ToGitObject[repo_GitRepo, obj_GitObject] := (Message[ToGitObject::mismatchedgitobj, obj, repo]; obj);
ToGitObject[__] := $Failed;


$GitRepos = {};
GitRepos[] := $GitRepos;
GitRepos[abspath:(_String|_StringExpression)] := Select[$GitRepos,
	StringMatchQ[First[#], abspath,
		IgnoreCase -> ($OperatingSystem === "Windows" || $OperatingSystem === "MacOSX")]&
];


(* ::Subsection::Closed:: *)
(*Visualization*)


nodeLabelFunction[o_GitObject]:=
Labeled[o,
	Placed[
		Tooltip[
			Framed[StringTake[GitSHA[o],8],RoundingRadius->5,Background->RGBColor[0.9,1.,0.9]],
			Dataset[GitProperties[o]]
		], Center]]/;GitType[o]==="Commit";


nodeLabelFunction[o_GitObject]:=
Labeled[o,
	Placed[
		Tooltip[
			Framed[StringTake[GitSHA[o],8],RoundingRadius->5,Background->RGBColor[0.95,0.9,0.95]],
			Dataset[GitExpandTree[o]]
		], Center]]/;GitType[o]==="Tree";


nodeLabelFunction[o_GitObject]:=
Labeled[o,
	Placed[
		Tooltip[
			Framed[StringTake[GitSHA[o],8],RoundingRadius->5,Background->RGBColor[0.95,0.9,0.95]],
			GitReadBlob[o]
		], Center]]/;GitType[o]==="Blob";


computeEdges[commitList_, treeList_, firstLevelList_]:=
Module[{nodeList=Join[commitList,treeList,firstLevelList]},
Cases[Join[
			Flatten[Function[c,{c\[DirectedEdge]#&/@c["Parents"],c\[DirectedEdge]c["Tree"]}]/@commitList],
			If[firstLevelList==={},{},Flatten[Function[t,{t\[DirectedEdge]#&/@(GitExpandTree[t][[All,"Object"]])}]/@treeList]]
		],Alternatives@@nodeList\[DirectedEdge]Alternatives@@nodeList]];


GitGraph[r_GitRepo, objs_String]:= GitGraph[GitRange[r, "master"], objs];
GitGraph[commitList:{___GitObject}, objs_String] :=
Module[{nodeList, treeList, firstLevelList},
	treeList=If[StringMatchQ[objs, "Trees"|"Blobs"], #["Tree"]&/@commitList, {}];
	firstLevelList=If[objs==="Blobs", Union[Flatten[GitExpandTree/@treeList][[All, "Object"]]], {}];
	nodeList=nodeLabelFunction/@Join[commitList, treeList, firstLevelList];
	Graph[nodeList, computeEdges[commitList, treeList, firstLevelList],
		GraphLayout->{"GridEmbedding", "Dimension"->{3,3}},
		EdgeShapeFunction->GraphElementData["FilledArrow", "ArrowSize"->0.05],
		BaseStyle->{TooltipBoxOptions->{LabelStyle->
			{Magnification->Dynamic@AbsoluteCurrentValue[EvaluationNotebook[], Magnification]}}}
	]]


(* ::Subsection::Closed:: *)
(*Git commands*)


(* ::Subsubsection::Closed:: *)
(*Repo management*)


GitOpen[path_String]:=
	Module[{abspath = AbsoluteFileName[path], repos, repo},
		repos = GitRepos[abspath];
		Which[
			MatchQ[repos, {(_ -> _GitRepo)..}], repos[[1,2]],
			StringQ[abspath] && GitRepoQ[abspath],
				repo = GL`GitOpen[abspath];
				PrependTo[$GitRepos, abspath -> repo];
				repo,
			True, $Failed]
	];


(* FIXME: Implement *)
GitClose[repo_GitRepo] := (
	GL`GitClose[repo["GitDirectory"]];
	$GitRepos = Select[$GitRepos, #["GitDirectory"] != repo["GitDirectory"]&];
)


(* ::Subsubsection::Closed:: *)
(*Repo creation*)


Options[GitClone] = {"Bare" -> False, "ProgressMonitor" -> None};

GitClone[uri_String, opts:OptionsPattern[]] :=
	Module[{dirName = Last[StringSplit[uri, "/"|"\\"]]},
		dirName = StringReplace[dirName, c__~~".git"~~EndOfString :> c];
		GitClone[uri, FileNameJoin[{Directory[], dirName}], opts]
	];
GitClone[uri_String, localPath_String, OptionsPattern[]] :=
	Catch[Module[{result, source = uri, dir = ExpandFileName[localPath], dirExistedQ, initrepo},
		If[Not[MatchQ[URLParse[uri, "Scheme"], "http" | "https" | "ssh" | "file"]] &&
			Not[StringQ[source = AbsoluteFileName[uri]]],
			Message[GitClone::nosrcdir, uri]; Throw[$Failed, GitClone]];
		dirExistedQ = DirectoryQ[dir];
		(* GL`GitClone doesn't create the directories with the
			right permissions.  GitInit does.  So init, then clean it out. *)
		If[GitRepoQ[dir],
			Message[GitClone::nooverwrite]; Throw[$Failed, GitClone]];
		initrepo = GitInit[dir];
		If[!MatchQ[initrepo, _GitRepo],
			Message[GitClone::nocreate]; Throw[$Failed, GitClone]];
		DeleteDirectory[FileNameJoin[{dir, ".git"}],DeleteContents->True];
		result = GL`GitClone[source, dir, $GitCredentialsFile,
			TrueQ @ OptionValue["Bare"],
			OptionValue["ProgressMonitor"]
		];
		(* If the clone failed and the directory didn't exist before, delete it. *)
		If[result === $Failed && Not[dirExistedQ] && DirectoryQ[dir],
			DeleteDirectory[dir, DeleteContents -> True]
		];
		result
	], GitClone]


Options[GitInit] = {"Bare" -> False, "Description" -> None, "Overwrite" -> False, "WorkingDirectory" -> None};

GitInit[path_String, opts:OptionsPattern[]] := Catch[Module[{result},
	If[GitRepoQ[path],
		Message[GitInit::nooverwrite]; Throw[$Failed, GitInit]];
	result = GL`GitInit[ExpandFileName[path], OptionValue["WorkingDirectory"],
		OptionValue["Bare"], OptionValue["Description"], OptionValue["Overwrite"]];
	If[MatchQ[result, _GitRepo], PrependTo[$GitRepos, AbsoluteFileName[path] -> result]];
	result],
GitInit]


(* ::Subsubsection::Closed:: *)
(*Commit creation*)


Options[GitCommit] = {"AuthorSignature"->Automatic, "CommitterSignature"->Automatic};

GitCommit[repo_GitRepo, log_String, tree_, parents_List, opts:OptionsPattern[]] :=
	Catch[Module[
		{resolvedTree = tree,
		indexTree = GL`GitIndexTree[repo],
		resolvedParents = ToGitObject[repo, #]& /@ parents,
		result},

		(* figure out the tree to be committed *)
		If[resolvedTree === Automatic, resolvedTree = indexTree];
		If[GitType[resolvedTree] =!= "Tree",
			Message[GitCommit::notree]; Throw[$Failed, GitCommit]];
		If[!AllTrue[resolvedParents, GitCommitQ],
			Message[GitCommit::badcommitish]; Throw[$Failed, GitCommit]];

		(* create the commit *)
		result = GL`GitCommit[repo["GitDirectory"], log, resolvedTree, resolvedParents,
			OptionValue["AuthorSignature"], OptionValue["CommitterSignature"]];

		(* resolve what to do about HEAD *)
		Which[
			!GitCommitQ[result] || TrueQ[GitProperties[repo, "BareQ"]],
				0,
			repo["EmptyQ"],
				GitCreateBranch[repo, "master", result],
			parents === {},
				0,
			indexTree === resolvedTree && isHeadBranch[repo, parents[[1]]],
				GitMoveBranch[repo["HeadBranch"], result],
			indexTree === resolvedTree && ToGitObject[repo, parents[[1]]] === ToGitObject[repo, "HEAD"], (* detached *)
				GL`GitSetHead[repo["GitDirectory"], GitSHA[result]],
			isHeadBranch[repo, parents[[1]]],
				relocateHeadBranchIfItExists[repo, result, GitCommit],
			parents[[1]] === "HEAD", (* detached *)
				GitCheckoutReference[repo, result],
			GitBranchQ[repo, parents[[1]]],
				GitMoveBranch[parents[[1]], result]
		];
		result
	], GitCommit];

GitCommit[repo_GitRepo, log_String, tree_, None, opts:OptionsPattern[]] :=
	GitCommit[repo, log, tree, {}, opts];
GitCommit[repo_GitRepo, log_String, tree_, parent_, opts:OptionsPattern[]] :=
	GitCommit[repo, log, tree, {parent}, opts];
GitCommit[repo_GitRepo, log_String, tree_:Automatic, opts:OptionsPattern[]] :=
	GitCommit[repo, log, tree, If[ToGitObject[repo, "HEAD"]===$Failed, {}, {"HEAD"}], opts];


Options[GitCherryPick] = {};

(* flaky...returns true false with a changed index...decide what to do here *)
GitCherryPick[repo_GitRepo, commit:(_String|_GitObject), branch_String, OptionsPattern[]] :=
	GL`GitCherryPick[repo["GitDirectory"], commit];

(* much better...returns the SHA of the new commit or $Failed *)
GitCherryPick[repo_GitRepo, fromCommit:(_String|_GitObject), toCommit:(_String|_GitObject), reference_String] :=
	GL`GitCherryPickCommit[repo["GitDirectory"], fromCommit, toCommit, reference];
GitCherryPick[___] := $Failed;


Options[GitMerge] = {
	"CommitMessage"->None,
	"ConflictFunctions"-><||>,
	"FinalFunctions"-><||>,
	"ProgressMonitor"->None,
	"AllowCommit"->True,
	"AllowFastForward"->True,
	"AllowIndexChanges"->True,
	"MergeStrategy"->{}};

GitMerge[repo_GitRepo, source_List, dest:(None|_String):"HEAD", OptionsPattern[]] :=
	Catch[Module[{result, oldCommit,realDest},
		realDest = If[dest === "HEAD" && KeyExistsQ[GitProperties[repo], "HeadBranch"],
						GitProperties[repo, "HeadBranch"],
						dest];
		If[realDest =!= None && !GitBranchQ[repo, realDest],
			Message[GitMerge::nobranch]; Throw[$Failed, GitMerge]];

		(* Create commit *)
		If[realDest =!= None, oldCommit = ToGitObject[repo, realDest]];
		result = GL`GitMerge[repo["GitDirectory"], source, realDest,
			OptionValue["CommitMessage"],
			{OptionValue["ConflictFunctions"], OptionValue["FinalFunctions"], OptionValue["ProgressMonitor"]},
			OptionValue["AllowCommit"],
			OptionValue["AllowFastForward"],
			OptionValue["AllowIndexChanges"],
			OptionValue["MergeStrategy"]
		];

		(* Branch management *)
		(* i.e., create "WOLFRAM_PULL_HEAD" at result, check it out, move realDest, then *)
		(* set HEAD to realDest and clean up *)
		If[realDest =!= None,
			relocateHeadBranchIfItExists[repo, result, GitMerge]];

		result],
	GitMerge];

GitMerge[repo_GitRepo, source:(_String|_GitObject), dest:(None|_String):"HEAD", opts:OptionsPattern[]] :=
	GitMerge[repo, {source}, dest, opts];


(* ::Subsubsection::Closed:: *)
(*Remote communication*)


Options[GitFetch] = {"Prune" -> Automatic, "DownloadTags" -> Automatic};

GitFetch[repo_GitRepo, remote_String, OptionsPattern[]] :=
	GL`GitFetch[repo["GitDirectory"], remote, $GitCredentialsFile, TrueQ @ OptionValue["Prune"], OptionValue["DownloadTags"]];


Options[GitPull] = Union[Options[GitMerge], Options[GitFetch]];

GitPull[repo_GitRepo, remote:(_String|None), commit_GitObject, opts:OptionsPattern[]] :=
	Catch[
		If[remote =!= None && !GitRemoteQ[repo, remote],
			Message[GitPull::badremote]; Throw[$Failed, GitPull]];
		If[!GitCommitQ[commit],
			Message[GitPull::badcommit]; Throw[$Failed, GitPull]];
		If[TrueQ[GitProperties[repo, "DetachedHeadQ"]],
			Message[GitPull::detachedhead]; Throw[$Failed, GitPull]];

		If[remote =!= None,
			GitFetch[repo, remote, Sequence @@ FilterRules[Flatten[{opts}], Options[GitFetch]]]];
		GitMerge[repo, commit, Sequence @@ FilterRules[Flatten[{opts}], Options[GitMerge]]],
	GitPull];

GitPull[repo_GitRepo, remote:(_String|None), branch_String, opts:OptionsPattern[]] :=
	Module[{commit = $Failed, remoteArg = remote},
		If[StringQ[remote] && GitRemoteQ[repo, remote],
			GitFetch[repo, remote, Sequence @@ FilterRules[Flatten[{opts}], Options[GitFetch]]];
			commit = ToGitObject[repo, remote <> "/" <> branch];
			remoteArg = None; (* prevent a double-fetch *)
		];
		If[commit === $Failed, commit = ToGitObject[repo, branch]];
		GitPull[repo, remoteArg, commit, opts]
	];

GitPull[repo_GitRepo, remote:(_String|None), opts:OptionsPattern[]] :=
	Module[{upstreamBranch, realRemote = remote},
		upstreamBranch = Quiet@GitUpstreamBranch[repo, GitProperties[repo, "HeadBranch"]];
		If[StringQ[upstreamBranch],

			If[realRemote === None,
				realRemote = FileNameSplit[upstreamBranch][[1]];
				If[!GitRemoteQ[realRemote], realRemote = None]];
			If[realRemote =!= None,
				GitFetch[repo, realRemote, Sequence @@ FilterRules[Flatten[{opts}], Options[GitFetch]]]];
			GitPull[repo, None, ToGitObject[repo, upstreamBranch], opts],

			Message[GitPull::noupstream]; $Failed]
	];

GitPull[repo_GitRepo, opts:OptionsPattern[]] := GitPull[repo, None, opts];


Options[GitPush] = {};

GitPush[repo_GitRepo, remote_String, branch_String, OptionsPattern[]] :=
	GL`GitPush[repo["GitDirectory"], remote, $GitCredentialsFile, branch];


(* ::Subsubsection::Closed:: *)
(*Index management*)


Options[GitAdd] = {"Force"->False};

(* returns True/False, sets the branch on the given commit *)
GitAdd[repo_GitRepo, path_String, OptionsPattern[]] :=
	Module[{relativePath = path}, (* fixme *)
		GL`GitAddRemovePath[repo["GitDirectory"], relativePath, "GitAdd", OptionValue["Force"]]
	];
GitAdd[repo_GitRepo, All, opts:OptionsPattern[]] := GitAdd[repo, "*", opts]
GitAdd[repo_GitRepo, paths:{___String}, opts:OptionsPattern[]] :=
	Flatten[GitAdd[repo, #, opts]& /@ paths]


Options[GitReset] = {};

(* returns True/False, sets the branch on the given commit *)
GitReset[repo_GitRepo, path_String, OptionsPattern[]] :=
	Module[{relativePath = path}, (* fixme *)
		GL`GitAddRemovePath[repo["GitDirectory"], relativePath, "GitReset", False]
	];
GitReset[repo_GitRepo, All, opts:OptionsPattern[]] := GitReset[repo, "*", opts]
GitReset[repo_GitRepo, paths:{___String}, opts:OptionsPattern[]] :=
	Flatten[GitReset[repo, #, opts]& /@ paths]


(* ::Subsubsection::Closed:: *)
(*Branch management*)


Options[GitCreateBranch] = {"Checkout"->False, "Force"->False, "UpstreamBranch"->None};

(* returns True/False, sets the branch on the given commit *)
GitCreateBranch[repo_GitRepo, branch_String, commit:(_String|_GitObject):"HEAD", OptionsPattern[]] :=
	Module[{result = GL`GitCreateBranch[repo["GitDirectory"], branch, commit, TrueQ[OptionValue["Force"]]],
			remoteBranches = repo["RemoteBranches"]},
		Which[
			!result,
				Null,
			MemberQ[remoteBranches, OptionValue["UpstreamBranch"]],
				GitSetUpstreamBranch[repo, branch, OptionValue["UpstreamBranch"]],
			OptionValue["UpstreamBranch"] === Automatic && MemberQ[remoteBranches, commit],
				GitSetUpstreamBranch[repo, branch, commit],
			True,
				Null
		];
		If[result && TrueQ[OptionValue["Checkout"]], GitCheckoutReference[repo, branch]];
		result
	];


Options[GitDeleteBranch] = {"Force"->False, "RemoteBranch"->False};

(* returns Null/$Failed, deletes the given branch *)
GitDeleteBranch[repo_GitRepo, branch_String, OptionsPattern[]] :=
	GL`GitDeleteBranch[repo["GitDirectory"], branch, TrueQ[OptionValue["Force"]], TrueQ[OptionValue["RemoteBranch"]]];


Options[GitMoveBranch] = {};

(* returns True/False, sets the branch on the given commit *)
GitMoveBranch["HEAD", obj:GitObject[_String, repo_GitRepo], source_:None, opts:OptionsPattern[]] :=
	GitMoveBranch[GitProperties[repo]["HeadBranch"], obj, source, opts];
GitMoveBranch[branch_String, GitObject[dest_String, repo_GitRepo], source_:None, OptionsPattern[]] :=
	GL`GitMoveBranch[
		repo["GitDirectory"],
		StringReplace[branch, StartOfString~~"refs/heads/"~~val__:>val],
		dest, source
	];


Options[GitUpstreamBranch] = {};

(* returns the upstream branch for the given branch, or None if there is none, or $Failed *)
GitUpstreamBranch[repo_GitRepo, branch_String, OptionsPattern[]] :=
	GL`GitUpstreamBranch[repo["GitDirectory"], branch];


Options[GitSetUpstreamBranch] = {"Force"->False};

(* returns True/False, sets the branch on the given commit *)
GitSetUpstreamBranch[repo_GitRepo, branch_String, upstreamBranch_String, OptionsPattern[]] :=
	If[TrueQ[OptionValue["Force"]] || Quiet[MatchQ[GitUpstreamBranch[repo, branch], None|upstreamBranch]],
		GL`GitSetUpstreamBranch[repo["GitDirectory"], branch, upstreamBranch],
		False];


Options[GitCreateTrackingBranch] = {};

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


(* ::Subsubsection::Closed:: *)
(*Tag management*)


Options[GitCreateTag] = {"Force"->False, "Signature"->Automatic};

(* returns True/False *)
GitCreateTag[repo_GitRepo, tag_String, commit:(_String|_GitObject):"HEAD", message:(None|_String):None, OptionsPattern[]] :=
	GL`GitCreateTag[repo["GitDirectory"], tag, commit, message, TrueQ[OptionValue["Force"]], OptionValue["Signature"]];


Options[GitDeleteTag] = {};

(* returns Null/$Failed, deletes the given tag(s) *)
GitDeleteTag[repo_GitRepo, tag_String, OptionsPattern[]] := GL`GitDeleteTag[repo["GitDirectory"], tag];
GitDeleteTag[repo_GitRepo, tags:{___String}] := GitDeleteTag[repo, #]& /@ tags /. {{Null...}->Null, _->$Failed};


(* ::Subsubsection::Closed:: *)
(*Remote management*)


Options[GitAddRemote] = {};

GitAddRemote[repo_GitRepo, remote_String, uri_String] :=
	GL`GitAddRemote[repo["GitDirectory"], remote, uri];


Options[GitDeleteRemote] = {};

GitDeleteRemote[repo_GitRepo, remote_String, OptionsPattern[]] :=
	GL`GitDeleteRemote[repo["GitDirectory"], remote];


(* ::Subsubsection::Closed:: *)
(*Working directory*)


Options[GitStatus] = {"DetectRenames" -> False, "IncludeIgnored" -> False, "RecurseUntrackedDirectories" -> False};

GitStatus[repo_GitRepo, opts:OptionsPattern[]] := GL`GitStatus[repo["GitDirectory"], OptionValue["DetectRenames"], OptionValue["IncludeIgnored"], OptionValue["RecurseUntrackedDirectories"]];

GitStatus[repo_GitRepo, All, opts:OptionsPattern[]] := GitStatus[repo];
GitStatus[repo_GitRepo, "Properties", opts:OptionsPattern[]] := Keys[GitStatus[repo, opts]];
GitStatus[repo_GitRepo, prop: (_String | {___String}), opts:OptionsPattern[]] := Lookup[GitStatus[repo, opts], prop];


(* FIXME...this is old code that needs to be updated for current documentation *)
Options[GitCheckoutFiles] = {"CheckoutStrategy"->{"Safe"}, "Notifications"-><||>};

GitCheckoutFiles[repo_GitRepo, refName_String, OptionsPattern[]] :=
	Module[{result},
		If[!GitCommitQ[repo, refName] && GitCreateTrackingBranch[repo, refName]===$Failed,

			Message[GitCheckoutFiles::refNotFound]; $Failed,
			result = If[refName === "HEAD", ToGitObject[repo, refName], GL`GitSetHead[repo["GitDirectory"], refName]];

			If[result =!= $Failed, GL`GitCheckoutHead[repo["GitDirectory"], OptionValue["CheckoutStrategy"], OptionValue["Notifications"]]];
			result
		]
	]


Options[GitCheckoutReference] = {
	"Create" -> False,
	"Force" -> False,
	"UpstreamBranch" -> Automatic,
	"UpstreamRemote" -> Automatic
};

GitCheckoutReference[repo_GitRepo, refName_String, OptionsPattern[]] :=
Module[{props = GitProperties[repo], localBranches, remoteBranches, remotes},
	localBranches = props["LocalBranches"];
	remoteBranches = Replace[OptionValue["UpstreamBranch"], {s_String :> {s}, _ :> props["RemoteBranches"]}];
	remotes = Replace[OptionValue["UpstreamRemote"], {s_String :> {s}, _ :> Keys[props["Remotes"]]}];

	If[!MemberQ[localBranches, refName],
		remoteBranches = Cases[remoteBranches, Alternatives @@ (# <> "/" <> refName &)/@ remotes];
		If[MatchQ[remoteBranches, {__String}],
			GitCreateBranch[repo, refName, First[remoteBranches], "UpstreamBranch" -> Automatic]
		]
	];
	Which[
		TrueQ @ OptionValue["Create"] && TrueQ @ GitCreateBranch[repo, refName, "Force" -> OptionValue["Force"], "Checkout" -> True],
			ToGitObject[repo, "HEAD"],
		TrueQ @ OptionValue["Create"],
			$Failed, (* FIXME...inconsistent return vals don't seem right *)
		ToGitObject[repo, refName] === $Failed,
			Missing["NoReference"],
		TrueQ[OptionValue["Force"]],
			GitCheckoutFiles[repo, refName, "CheckoutStrategy"->{"Force"}],
		True,
			GL`GitCheckoutReference[repo["GitDirectory"], refName]
	]
];

GitCheckoutReference[repo_GitRepo, commit_GitObject, opts:OptionsPattern[]] :=
	GitCheckoutReference[repo, GitSHA[commit], opts];


(* ::Subsubsection::Closed:: *)
(*Queries*)


Options[GitMergeBase] = {};

GitMergeBase[repo_GitRepo, commits__, OptionsPattern[]] :=
	GL`GitMergeBase[repo["GitDirectory"], commits];
GitMergeBase[commits:GitObject[_, repo_GitRepo].., OptionsPattern[]] :=
	GL`GitMergeBase[repo["GitDirectory"], commits];


(* ::Subsection::Closed:: *)
(*Bare metal Git operations*)


Options[GitExpandTree] = {};

(* returns a list of GitObjects *)
GitExpandTree[obj_GitObject, depth_:1] := 
	Switch[GitType[obj],
		"Commit"|"Tag", GL`GitExpandTree[GitProperties[obj]["Tree"], depth],
		"Tree", GL`GitExpandTree[obj, depth],
		_, obj];
GitExpandTree[objs:{___GitObject}, depth_:1] :=
	Map[GitExpandTree[#, depth]&, objs]


Options[GitWriteTree] = {};

(* returns a list of GitObjects *)
GitWriteTree[objs:{__Association}] := GL`GitWriteTree[objs]
GitWriteTree[objs_Dataset] := GitWriteTree[Normal[objs]]


(* returns files which are different between the two trees *)
(* some files may only exist in one of the trees *)
gitDiffTrees[tree1_GitObject, tree2_GitObject] :=
	GL`GitDiffTrees[tree1, tree2];


Options[GitReadBlob] = {CharacterEncoding->"UTF8", "PathNameHint"->None};

(* returns a list of GitObjects *)
GitReadBlob[blob_GitObject, format_:"String", o:OptionsPattern[]] :=
Module[{encoding=Quiet@OptionValue[CharacterEncoding], impOpts = FilterRules[{o}, Except[First /@ Options[GitReadBlob]]]},
With[{readblob = GL`GitReadBlob[#, blob, Quiet@OptionValue["PathNameHint"]]&},
	Which[
		format === "String" && encoding === "UTF8",
			Module[{data=readblob["ByteString"]},
				Quiet[Check[
					FromCharacterCode[ToCharacterCode[data], encoding],
					data,
					$CharacterEncoding::utf8], $CharacterEncoding::utf8]
			],
		MemberQ[$ImportFormats, format],
			ImportString[readblob["ByteString"], format, CharacterEncoding->encoding, Sequence@@impOpts],
		format === "HeldExpressions",
			Module[{str},
				str = ImportString[readblob["ByteString"], "Text", CharacterEncoding->encoding];
				Replace[ToExpression[str, InputForm, HoldComplete],
					HoldComplete[args___] :> DeleteCases[Map[HoldComplete, Unevaluated[{args}]], _[Null]]]
			],
		True,
			Message[GitReadBlob::badformat]; $Failed
	]
]]


Options[GitWriteBlob] = {CharacterEncoding->"UTF8", "PathNameHint"->None};

(* returns a list of GitObjects *)
GitWriteBlob[repo_GitRepo, expr_, format_:"String", o:OptionsPattern[]] :=
Module[{encoding=Quiet@OptionValue[CharacterEncoding], expOpts = FilterRules[{o}, Except[First /@ Options[GitWriteBlob]]]},
With[{writeblob = GL`GitWriteBlob[repo["GitDirectory"], #1, Quiet@OptionValue["PathNameHint"], #2]&},
	Which[
		format === "String" && StringQ[expr] && encoding === "UTF8",
			writeblob["UTF8String", expr],
		MemberQ[$ExportFormats, format],
			writeblob["ByteString", ExportString[expr, format, CharacterEncoding->encoding, Sequence@@expOpts]],
		True,
			Message[GitWriteBlob::badformat]; $Failed
	]
]]


(* ::Subsection::Closed:: *)
(*Merge utilities*)


(*
In handleConflicts[conflict], conflict is an association with these keys:

"OurFileName"
"OurBlob"
"TheirFileName"
"TheirBlob"
"AncestorFileName"
"AncestorBlob"
"Repo"
"ConflictFunctions"

If the conflict handling is successful, return a new blob. Otherwise, return $Failed.
*)


(*
$DefaultConflictFunctions is an association containing fall-through settings. They
are ony reached if the "ConflictFunctions" in the conflict don't have any keys matching
the file names in question.
*)
$DefaultConflictFunctions = <|
	(__ ~~ ".nb") -> "StandardNotebookMerge"
|>;


Options[handleConflicts] = {};

showProgress = StashLink`Private`showProgress;
showProgressQ := TrueQ[StashLink`Private`$bankPrototypeUpdate];

handleConflicts[conflict_Association] :=
Catch[Module[{cf, cflog, ancestorfilename, cfkey, result},
	(* choose the conflict function based on the "AncestorFileName" *)
	cf = Join[
		Cases[Normal[conflict["ConflictFunctions"]], _Rule],
		Cases[Normal[$DefaultConflictFunctions], _Rule]
	];
	ancestorfilename = conflict["AncestorFileName"];
	Which[
		(* If there is no ancestor file name, do nothing *)
		!StringQ[ancestorfilename],
			Message[handleConflicts::noancfile]; Throw[$Failed, handleConflicts],
		(* If there's an exact match, use it. *)
		MemberQ[ancestorfilename, Keys[cf]],
			cfkey = ancestorfilename,
		(* If there's a string match, use the first one. *)
		cfkey = SelectFirst[Keys[cf], StringMatchQ[ancestorfilename, #]&, None];
		cfkey =!= None,
			Null,
		(* otherwise, there's no appropriate conflict function. Return $Failed *)
		True,
			Message[handleConflicts::noconfunc]; Throw[$Failed, handleConflicts]
	];

	cf = cflog = Lookup[cf, cfkey];
	(* If the conflict function resolves to a string, use the built-in conflictHandler with that string as the merge type *)
	Replace[cf, mergetype_String :> (cf = conflictHandler[#, mergetype]&)];

	(* if running the conflict function on this conflict returns anything other than a GitObject, return $Failed *)
	result = Replace[cf[conflict], Except[_Association] :> $Failed];
	If[showProgressQ,
		If[result === $Failed,
			showProgress["conflict not resolved via `1`", cflog, conflict],
			showProgress["`1` merged via `2`: `3`", result["FileName"], cflog, GitSHA @ result["Blob"]]
		]
	];
	result

], handleConflicts]


conflictHandler[conflict_Association, mergetype: "MessagesMerge"] := conflictHandler[conflict, "ChooseBothLines"]


(* "ChooseOurs" and "ChooseTheirs" are format-agnostic. Use "Byte" for universality. *)
conflictHandler[conflict_Association, mergetype: ("ChooseOurs" | "ChooseTheirs")] :=
Catch[Module[{repo, blob, format},
	repo = conflict["Repo"];
	blob = If[mergetype === "ChooseOurs", conflict["OurBlob"], conflict["TheirBlob"]];
	format = "Byte";
	If[MemberQ[{blob, repo}, _Missing],
		Message[handleConflicts::invassoc]; Throw[$Failed, conflictHandler]];

	blob = GitReadBlob[blob, format];
	<|
		"Blob" -> GitWriteBlob[repo, blob, format],
		"FileName" -> If[mergetype === "ChooseOurs", conflict["OurFileName"], conflict["TheirFileName"]]
	|>

], conflictHandler]


conflictHandler[conflict_Association, mergetype: "ChooseBothLines"] :=
Catch[Module[{ancestor, our, their, repo, format, aligned, merged},

	{ancestor, our, their, repo} = conflict /@ {"AncestorBlob", "OurBlob", "TheirBlob", "Repo"};
	If[MemberQ[{ancestor, our, their, repo}, _Missing],
		Message[handleConflicts::invassoc]; Throw[$Failed, conflictHandler]];
	If[Not[conflict["OurFileName"] === conflict["TheirFileName"] === conflict["AncestorFileName"]],
		Message[handleConflicts::invassoc]; Throw[$Failed, conflictHandler]];

	format = "String";
	{ancestor, our, their} = GitReadBlob[#, format]& /@ {ancestor, our, their};
	If[MemberQ[{ancestor, our, their}, Except[_String]],
		Message[handleConflicts::gitreadbloberr]; Throw[$Failed, conflictHandler]];

	{ancestor, our, their} = ImportString[#, "Lines"]& /@ {ancestor, our, their};
	If[MemberQ[{ancestor, our, their}, Except[_List]],
		Message[handleConflicts::importerr]; Throw[$Failed, conflictHandler]];

	aligned = NotebookTools`MultiAlignment[ancestor, our, their];

	merged = Flatten[Replace[aligned, {
			{a_List, b_List, a_List} (* changed by us *) :> b, 
			{a_List, a_List, b_List} (* changed by them *) :> b,
			{a_List, b_List, b_List} (* changed identically in both *) :> b, 
			{a_List, b_List, c_List} (* changed differently in both *) :> {b,c} }, {1}]];
	merged = ExportString[merged, "Lines"];

	<|
		"Blob" -> GitWriteBlob[repo, merged, format],
		"FileName" -> conflict["OurFileName"]
	|>

], conflictHandler]


(*
The "MergeLoad.m" handler is intended for files which contain a single Join[]
expression. The merge will include changes made to this Join from either file,
as long as there are no direct conflicts.
*)
conflictHandler[conflict_Association, mergetype: "MergeLoad.m"] :=
Catch[Module[{ancestor, our, their, repo, format, aligned, merged},

	{ancestor, our, their, repo} = conflict /@ {"AncestorBlob", "OurBlob", "TheirBlob", "Repo"};
	If[MemberQ[{ancestor, our, their, repo}, _Missing],
		Message[handleConflicts::invassoc]; Throw[$Failed, conflictHandler]];
	If[Not[conflict["OurFileName"] === conflict["TheirFileName"] === conflict["AncestorFileName"]],
		Message[handleConflicts::invassoc]; Throw[$Failed, conflictHandler]];

	format = "HeldExpressions";
	{ancestor, our, their} = GitReadBlob[#, format]& /@ {ancestor, our, their};
	If[MemberQ[{ancestor, our, their}, Except[{HoldComplete[Join[___]]}]],
		Message[handleConflicts::atypicalload]; Throw[$Failed, conflictHandler]];

	{ancestor, our, their} = Replace[{ancestor, our, their},
		{HoldComplete[Join[args___]]} :> HoldComplete /@ Unevaluated[{args}], {1}];

	aligned = NotebookTools`MultiAlignment[ancestor, our, their];

	merged = Flatten[Replace[aligned, {
			{a_List, b_List, a_List} (* changed by us *) :> b, 
			{a_List, a_List, b_List} (* changed by them *) :> b,
			{a_List, b_List, b_List} (* changed identically in both *) :> b, 
			{a: { }, b_List, c_List} (* added in both *) :> DeleteDuplicates[Join[b, c]],
			{a_List, b_List, c_List} (* changed differently in both *) :> (
				Message[handleConflicts::conflict]; Throw[$Failed, conflictHandler]) }, {1}]];

	(* transform {___HoldComplete} to HoldComplete[Join[___]] *)
	merged = Join @@@ Thread[merged, HoldComplete];
	(* create the merged file's contents, as a string *)
	merged = Replace[merged, HoldComplete[arg_] :>
		Block[{Internal`$ContextMarks=True}, ToString[Unevaluated[arg], InputForm, PageWidth -> 90]]];

	<|
		"Blob" -> GitWriteBlob[repo, merged, "String"],
		"FileName" -> conflict["OurFileName"]
	|>

], conflictHandler]


(* "StandardNotebookMerge" uses NotebookMerge3 to do a standard 3-way merge *)
conflictHandler[conflict_Association, mergetype: "StandardNotebookMerge"] :=
Catch[Module[{ancestor, our, their, repo, merged, notebookSignedQ},

	{ancestor, our, their, repo} = conflict /@ {"AncestorBlob", "OurBlob", "TheirBlob", "Repo"};
	If[MemberQ[{ancestor, our, their, repo}, _Missing],
		Message[handleConflicts::invassoc]; Throw[$Failed, conflictHandler]];
	If[Not[conflict["OurFileName"] === conflict["TheirFileName"] === conflict["AncestorFileName"]],
		Message[handleConflicts::invassoc]; Throw[$Failed, conflictHandler]];

	(* If any of the notebook files are signed, don't attempt the merge *)
	notebookSignedQ[str_String] :=
		StringLength[str] > 300 && StringContainsQ[StringTake[str, -300], "(* NotebookSignature"];
	notebookSignedQ[other_] := False;
	If[AnyTrue[notebookSignedQ] @ {
		GitReadBlob[ancestor, "String"], GitReadBlob[our, "String"], GitReadBlob[their, "String"]},
		Message[handleConflicts::signednb]; Throw[$Failed, conflictHandler] ];

	StandardNotebookBlock[
		{ancestor, our, their} = GitReadBlob[#, "NB"]& /@ {ancestor, our, their};
		If[MemberQ[{ancestor, our, their}, Except[_Notebook]],
			Message[handleConflicts::gitreadbloberr]; Throw[$Failed, conflictHandler]];

		merged = NotebookMerge3`NotebookMerge3[ancestor, our, their];
		If[!StringQ[merged],
			Message[handleConflicts::nbmergefail]; Throw[$Failed, conflictHandler]];
	];

	<|
		"Blob" -> GitWriteBlob[repo, merged, "Text"],
		"FileName" -> conflict["OurFileName"]
	|>

], conflictHandler]


(*
StandardNotebookBlock[expr] processes expr in a way that hopefully minimizes gratuitous changes to
notebook files processed during evaluation of expr.

This prevents Infinity from becoming DirectedInfinity[1], option settings from reevaluating, and
any unrecognized symbols are assumed to be in the System` context.
*)
SetAttributes[StandardNotebookBlock, HoldAllComplete];
StandardNotebookBlock[expr_] := 
	Block[{Rule, eRule, Infinity, $Context = "System`"},
		SetAttributes[{Rule}, HoldRest];
		(* Allow Rule to evaluate for some LHSs *)
		Rule[name:(LinkProtocol | CharacterEncoding), value_] := eRule[name, value] /; $eRule =!= True;
		eRule[name_, value_] := Block[{$eRule = True}, Rule[name, value]];
		expr
	]


(*
TODO:
Three-way merging of stylesheets could be more forgiving than "StandardNotebookMerge".
* The order of StyleData cells in the notebook can be mostly ignored.
* The order of options within a particular StyleData cell can be ignored.
* Merging different changes into the same StyleData cell is feasible, as long as there
are no direct conflicts for individual option setting changes.
*)


conflictHandler[conflict_Association, mergetype_] := (Message[conflictHandler::unknownmergetype, mergetype]; $Failed)


(* ::Subsection::Closed:: *)
(*Typeset rules*)


giticon = Graphics[{EdgeForm[Gray],
	Gray, Thickness[0.1], Line[{{0,0},{5,0}}], Line[{{0,0},{5,-3}}],
	LightGray, Disk[{0,0},1], Disk[{5,0},1], Green, Disk[{5,-3},1]}, ImageSize -> 15];


BoxForm`MakeConditionalTextFormattingRule[GitRepo];

GitRepo /: MakeBoxes[GitRepo[assoc_Association], fmt_] :=
With[{
	icon = ToBoxes[giticon],
	name = Replace[assoc @ If[assoc @ "BareQ", "GitDirectory", "WorkingDirectory"], {a_String :> ToBoxes[a, fmt], _ :> MakeBoxes[assoc, fmt]}],
	tooltip = ToString[GitRepo[assoc], InputForm]},

	TemplateBox[{MakeBoxes[assoc, fmt]}, "GitRepo",
			DisplayFunction -> (
				TooltipBox[PanelBox[GridBox[{{icon, name}}, BaselinePosition -> {1,2}],
					FrameMargins -> 5, BaselinePosition -> Baseline], tooltip]&)]
]


BoxForm`MakeConditionalTextFormattingRule[GitObject];

GitObject /: MakeBoxes[obj:GitObject[sha_String, repo_GitRepo], fmt_] :=
Block[{shortsha, dir, type, bg, display},
	(*
		String and GitRepo are typically inert, so perhaps the evaluation leaks 
		here aren't that serious.
	*)
	shortsha = StringTake[sha, Min[8, StringLength[sha]]];
	dir = GitProperties[repo, "WorkingDirectory"];
	type = Replace[GitType[obj], Except[_String] :> "UnknownType"];
	If[type === "Tag", shortsha = GitProperties[obj, "TagName"]];

	bg = Switch[type,
		"Commit" | "Tag", Lighter[Green, 0.9],
		"Tree" | "Blob", Lighter[Purple, 0.9],
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
(*propertiesPanel*)


propertiesPanel[repo_GitRepo] := propertiesPanel[repo, GitProperties[repo]]

propertiesPanel[repo_GitRepo, properties_Association] := 
	Panel[Column[Flatten[{
		Item[Style["GitRepo Properties:", Bold], Alignment -> Center],
		Column[{
			Style["Working Directory:", Bold],
			properties["WorkingDirectory"]
		}],
		Column[{
			Style["Local Branches:", Bold],
			Replace[properties["LocalBranches"], { branches: {__} :> branchHierarchy[repo, "", branches], _ :> "-none-"}]
		}],
		Column[{
			Style["Remote Branches:", Bold],
			Replace[properties["RemoteBranches"], { branches: {__} :> branchHierarchy[repo, "", branches], _ :> "-none-"}]
		}],
		Column[Flatten[{
			Style["Remotes:", Bold],
			Replace[properties["Remotes"], {
				remotes_Association :>
					Table[
						OpenerView[{remote, Grid[List @@@ Normal[remotes[remote]], Alignment -> Left]}, False, Method -> "Active"],
						{remote, Keys[remotes]}
					],
				_ -> {"-none-"}
			}]
		}]],

		OpenerView[{
			Style["Other Properties:", Bold],
			Grid[
				Replace[
					DeleteCases[List @@@ Normal[properties], {("LocalBranches" | "RemoteBranches" | "Remotes" | "WorkingDirectory"), _}],
					{"Tags", tags: {_, __}} :> {"Tags", OpenerView[{Row[{Length[tags], " tags"}, BaseStyle -> Italic], Column[truncatedList[tags]]}, False]},
					{1}
				],
				Alignment -> Left
			]}, True],

		Replace[GitStatus[repo], {
			status_Association :> OpenerView[{Style["Status:", Bold], truncatedStatusGrid[status]}, False],
			_ -> {}
		}]

	}], Spacings -> 1.5, Dividers -> {{},{False,False,{True},False}}, FrameStyle -> LightGray, ItemSize -> Full]]

propertiesPanel[repo_GitRepo, _] := Panel[Row[{"No properties found for ", repo}]]


truncatedStatusGrid[status_Association] :=
	Module[{key, list, length, label, content},
		Grid[(
				key = First[#];
				list = Last[#];
				length = Length[list];
				label = Row[{length, " ", Pluralize[{"file", "files"}, length]}, BaseStyle -> Italic];
				truncatedList[list];
				content = If[list === {}, label, OpenerView[{label, Column[list]}, False]];
				{key, content}
			)& /@ Normal[status],
			Alignment -> Left
		]
	]

truncatedList[list_] := With[{length = Length[list], max = 10, crossover = 15},
	If[length > crossover, Append[Take[list, max], Row[{"and ", length-max, " more\[Ellipsis]"}, BaseStyle -> Italic]], list] ]


propertiesPanel[obj_GitObject] := propertiesPanel[obj, GitProperties[obj]]

propertiesPanel[obj_GitObject, properties_Association] :=
	Panel[Grid[
		Join[
			{{Item[Style["GitObject Properties:", Bold], Alignment -> Center], SpanFromLeft}},
			List @@@ Normal[properties]
		],
		Alignment -> Left
	]]

propertiesPanel[obj_GitObject, _] := Panel[Row[{"No properties found for " obj}]]


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

GitRepoList["Flat"] := GitRepoList["Flat", GitRepoList[]]

GitRepoList["Flat", list_List] := Flatten[list //. {Menu[_, a_List] :> a, MenuItem[path_] :> path, MenuItem[label_, path_, ___] :> path}]


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
Module[{props = GitProperties[repo]},
	Column[Flatten[{
		chooseRepositoryMenu[Dynamic[repo]],
		Grid[{{
			Style[props @ "WorkingDirectory", Larger],
			Button[
				Dynamic[RawBoxes @ FEPrivate`FrontEndResource["FEBitmaps", "CircleXIcon"]],
				repo = None,
				Appearance -> None]
		}}],
		Column[{
			Style["Local Branches:", Bold],
			Replace[props @ "LocalBranches", { branches: {__} :> branchHierarchy[Dynamic[repo], Dynamic[branch], branches], _ :> "-none-"}]
		}],
		Column[{
			Style["Remote Branches:", Bold],
			Replace[props @ "RemoteBranches", { branches: {__} :> branchHierarchy[Dynamic[repo], Dynamic[branch], branches], _ :> "-none-"}]
		}],

		Grid[Join[
				{{Style["Other Properties:", Bold], SpanFromLeft}},
				DeleteCases[List @@@ Normal[props], {("LocalBranches" | "RemoteBranches" | "Remotes"), _}],
				{{"Remotes", Replace[props @ "Remotes", { remotes_Association :> Tooltip[Keys[remotes], remotes], _ -> {} }]}}
			],
			Alignment -> Left
		]
	}], Spacings -> 2, Dividers -> Center, FrameStyle -> LightGray, ItemSize -> Full]
]


branchicon = Graphics[{EdgeForm[Gray],
	Gray, Thickness[0.1], Line[{{0,0},{5,0}}], Line[{{0,0},{5,-3}}],
	LightGray, Disk[{0,0},1], Disk[{5,0},1], Green, Disk[{5,-3},1]}, ImageSize -> 15];

branchopenericon = Dynamic[RawBoxes[FEPrivate`ImportImage[FrontEnd`ToFileName[{"Popups", "CodeCompletion"}, "MenuItemDirectoryTiny.png"]]]];

(* Dynamic arguments *)
formatBranch[Dynamic[repo_], Dynamic[branch_], {prefix___, name_}] := 
With[{branchname = StringJoin[Riffle[{prefix, name}, "/"]]},
	Button[
		Row[{branchicon, " ", Tooltip[name, branchname]}, BaseStyle -> Dynamic[If[CurrentValue["MouseOver"] || branch === branchname, FontColor -> RGBColor[0,0.67,0], {}]]],
		branch = branchname,
		Appearance -> None,
		BaseStyle -> {},
		DefaultBaseStyle -> {}
	]
]
(* non-Dynamic argumens *)
formatBranch[repo_, branch_, {prefix___, name_}] := Row[{branchicon, " ", Tooltip[name, FileNameJoin[{prefix, name}]]}]


formatBranchOpener[repo_, branch_, {above___, here_}, allbranches_] := 
	OpenerView[{
		Row[{branchopenericon, " ", here}],
		Column[
			Module[{branches, subbranches},
				branches = Cases[allbranches, {above, here, name_} :> {above, here, name}];
				subbranches = Cases[allbranches, {above, here, next_, __} :> {above, here, next}];
				Join[
					formatBranch[repo, branch, #]& /@ Union[branches],
					formatBranchOpener[repo, branch, #, allbranches]& /@ Union[subbranches]
				]
			],
			BaselinePosition -> {1,1},
			ItemSize -> Full
		]
	}]

branchHierarchy[Dynamic[repo_], Dynamic[branch_], prop_String] := branchHierarchy[Dynamic[repo], Dynamic[branch], GitProperties[repo, prop]]

branchHierarchy[repo_, branch_, branchList: {___String}] := 
Module[{allbranches = StringSplit[branchList, "/"], branches, subbranches},
	branches = Cases[allbranches, {_}];
	subbranches = Cases[allbranches, {base_, __} :> {base}];
	Column[
		Join[
			formatBranch[repo, branch, #]& /@ Union[branches],
			formatBranchOpener[repo, branch, #, allbranches]& /@ Union[subbranches]
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
	}& /@ (GitProperties /@ commits),
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
(*GitCommit[ToGitObject[repo, "master"]]*)


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
(*Git init*)


(* ::Input:: *)
(*SetDirectory[$TemporaryDirectory];*)
(*initRepo = GitInit["init_test"]*)
(*bareInitRepo = GitInit["nested/init_test_bare","Bare"->True]*)
(*GitProperties[#,"BareQ"]&/@{initRepo,bareInitRepo}==={False,True}*)
(*GitInit["init_test"]===$Failed*)
(*GitInit["init_test","Overwrite"->True]*)
(*ResetDirectory[]*)


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
(*Sort[GitProperties[commit]["Parents"]]===Sort[ToGitObject[mergerepo,#]&/@{"origin/mergeA","origin/mergeB","HEAD@{1}"}]*)


(* ::Input:: *)
(*GitProperties[ GitMerge[mergeRepo, {"origin/mergeA", "origin/mergeB"}, None]]["Parents"]===Sort[ToGitObject[mergerepo,#]&/@{"origin/mergeA","origin/mergeB"}]*)


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
(*GitCheckoutReference[repo,"merge1"]*)
(*GitProperties[repo]["HEAD"]*)


(* ::Input:: *)
(*GitCheckoutReference[repo,GitSHA[repo,"origin/merge1"]]*)
(*GitProperties[repo]["HEAD"]*)


(* ::Input:: *)
(*GitCheckoutReference[repo,"origin/merge1"]*)
(*GitProperties[repo]["HEAD"]*)


(* ::Input:: *)
(*GitCheckoutReference[repo,"merge2","CheckoutStrategy"->{"Force"}]*)
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
(*Git trees, commits*)


(* ::Input:: *)
(*Quiet@DeleteDirectory[FileNameJoin[{$TemporaryDirectory,"testrepo"}],DeleteContents->True];SetDirectory[$TemporaryDirectory];*)
(*repo=GitClone["ssh://git@stash.wolfram.com:7999/~jfultz/testrepo.git"];*)
(*ResetDirectory[];*)


(* ::Input:: *)
(*Dataset[tree=GitExpandTree[GitProperties[ToGitObject[repo, "master"]]["Tree"]]]*)


(* ::Input:: *)
(*GitExpandTree[GitProperties[ToGitObject[repo, "master"]]["Tree"]]===GitExpandTree[ToGitObject[repo, "master"]]*)


(* ::Input:: *)
(*newsubtree=tree[[1;;3]];*)
(*newsubtreeobj=GitWriteTree[newsubtree]*)
(*Sort[newsubtree]===Sort[GitExpandTree[newsubtreeobj]]*)


(* ::Input:: *)
(*newtree=Prepend[tree[[4;;6]], <|"Object"->newsubtreeobj,"Name"->"fish","FileMode"->"Tree"|>];*)
(*newtreeobj=GitWriteTree[newtree]*)
(*Dataset[GitExpandTree[newtreeobj,1]]*)
(*Dataset[GitExpandTree[newtreeobj,Infinity]]*)


(* ::Input:: *)
(*sig=<|"Name"->"Michael Garibaldi","Email"->"garibaldi@b5.com","TimeStamp"->DateObject[List[2025,6,1],TimeObject[List[0,0,0.]],TimeZone->0.]|>;*)
(*GitCommit[repo,"Testing GitCommit",newtreeobj, "AuthorSignature"->GitProperties[ToGitObject[repo, "master"]]["Author"],*)
(*"CommitterSignature"->sig]*)
(*ToGitObject[repo, "HEAD"]===%*)
(*GitProperties[%%]["Author"]===GitProperties[ToGitObject[repo, "master~1"]]["Author"]*)
(*GitProperties[%%%]["Committer"]===sig*)
(*GitCreateBranch[repo, "myBranch", "origin/myBranch", "UpstreamBranch"->Automatic];*)
(*GitCommit[repo, "Testing branch commit", newtreeobj, "myBranch"]*)
(*ToGitObject[repo, "myBranch"] === %*)


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
