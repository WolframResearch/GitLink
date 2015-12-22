(* ::Package:: *)

BeginTestSection["Tag"]


Needs["GitLink`"];
$TestRepos = FileNameJoin[{NotebookDirectory[], "repos"}];
$RepoDirectory = FileNameJoin[{$TemporaryDirectory, "TagTestRepo"}];
Quiet[DeleteDirectory[$RepoDirectory, DeleteContents->True]];
$Repo = GitClone[FileNameJoin[{$TestRepos, "testrepo", ".gitted"}], $RepoDirectory];


VerificationTest[
	GitRepoQ[$RepoDirectory] && AssociationQ[GitProperties[$Repo]]
]


(* ::Subsubsection:: *)
(*Detect existing tags*)


VerificationTest[
	GitProperties[$Repo, "Tags"]
	,
	{"e90810b","foo/bar","foo/foo/bar","packed-tag","point_to_blob","test"}
]


(* ::Subsubsection:: *)
(*Delete multiple tags*)


VerificationTest[
	GitDeleteTag[$Repo, GitProperties[$Repo, "Tags"]] === Null
	&& GitProperties[$Repo, "Tags"] === {}
]


(* ::Subsubsection:: *)
(*Create a lightweight tag*)


VerificationTest[
	GitCreateTag[$Repo, "tag1"] === ToGitObject[$Repo, "HEAD"]
]


(* ::Subsubsection:: *)
(*Create a tag at a custom commit and delete it*)


VerificationTest[
	GitCreateTag[$Repo, "tag2", "HEAD~1"] === ToGitObject[$Repo, "HEAD~1"]
	&& GitSHA[$Repo, "tag2"] === GitSHA[$Repo, "HEAD~1"]
	&& GitDeleteTag[$Repo, "tag2"] === Null
	&& GitSHA[$Repo, "tag2"] === $Failed
]


(* ::Subsubsection:: *)
(*Create a dupe tag without force*)


VerificationTest[
	GitCreateTag[$Repo, "tag1", "HEAD~2"] === $Failed
	&& GitSHA[$Repo, "tag1"] === GitSHA[$Repo, "HEAD"],
	True,
	{GitCreateTag::gitoperationfailed}
]


(* ::Subsubsection:: *)
(*Create a dupe tag with force*)


VerificationTest[
	GitCreateTag[$Repo, "tag1", "HEAD~2", "Force"->True] === ToGitObject[$Repo, "HEAD~2"]
]


(* ::Subsubsection:: *)
(*Create an annotated tag*)


VerificationTest[
	sig = GitSignature[];

	GitType[GitCreateTag[$Repo, "tag/annotated", "HEAD", "An annotated tag", "Signature"->sig]] === "Tag"
]


(* ::Subsubsection:: *)
(*GitProperties on an annotated tag*)


VerificationTest[
	props = GitProperties[ToGitObject[$Repo, "tag/annotated"]];
	cprops = GitProperties[ToGitObject[$Repo, "HEAD"]];
	KeyDropFrom[cprops, "Type"];

	props["TagCommitter"] === sig
	&& props["TagMessage"] === "An annotated tag"
    && Merge[{props, cprops}, Last] === props
]


(* ::Subsubsection:: *)
(*Annotated tag on a tree*)


VerificationTest[
	tree = GitProperties[ToGitObject[$Repo, "HEAD"], "Tree"];

	GitType[GitCreateTag[$Repo, "treetag", tree, "the head tree"]] === "Tag"
	&& GitProperties[ToGitObject[$Repo, "treetag"], "TagTargetType"] === "Tree"
	&& GitProperties[ToGitObject[$Repo, "treetag"], "TagTarget"] === GitSHA[tree]
]


(* ::Subsubsection:: *)
(*Lightweight tags fail on non-commit objs*)


VerificationTest[
	GitCreateTag[$Repo, "lightweighttreetag", tree] === $Failed,
	True,
	{GitCreateTag::gitoperationfailed}
]


GitClose[$Repo];
DeleteDirectory[$RepoDirectory, DeleteContents->True];


EndTestSection[]
