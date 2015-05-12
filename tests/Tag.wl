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


(* ::Text:: *)
(*Detect existing tags*)


VerificationTest[
	GitProperties[$Repo, "Tags"]
	,
	{"e90810b","foo/bar","foo/foo/bar","packed-tag","point_to_blob","test"}
]


(* ::Text:: *)
(*Delete multiple tags*)


VerificationTest[
	GitDeleteTag[$Repo, GitProperties[$Repo, "Tags"]] === Null
	&& GitProperties[$Repo, "Tags"] === {}
]


(* ::Text:: *)
(*Create a lightweight tag*)


VerificationTest[
	GitCreateTag[$Repo, "tag1"] === ToGitObject["HEAD", $Repo]
]


(* ::Text:: *)
(*Create a tag at a custom commit and delete it*)


VerificationTest[
	GitCreateTag[$Repo, "tag2", "HEAD~1"] === ToGitObject["HEAD~1", $Repo]
	&& GitSHA[$Repo, "tag2"] === GitSHA[$Repo, "HEAD~1"]
	&& GitDeleteTag[$Repo, "tag2"] === Null
	&& GitSHA[$Repo, "tag2"] === $Failed
]


(* ::Text:: *)
(*Create a dupe tag without force*)


VerificationTest[
	GitCreateTag[$Repo, "tag1", "HEAD~2"] === $Failed
	&& GitSHA[$Repo, "tag1"] === GitSHA[$Repo, "HEAD"],
	True,
	{GitCreateTag::gitoperationfailed}
]


(* ::Text:: *)
(*Create a dupe tag with force*)


VerificationTest[
	GitCreateTag[$Repo, "tag1", "HEAD~2", "Force"->True] === ToGitObject["HEAD~2", $Repo]
]


(* ::Text:: *)
(*Create an annotated tag*)


VerificationTest[
	sig = GitSignature[];

	GitType[GitCreateTag[$Repo, "tag/annotated", "HEAD", "An annotated tag", "Signature"->sig]] === "Tag"
]


(* ::Text:: *)
(*GitProperties on an annotated tag*)


VerificationTest[
	props = GitProperties[ToGitObject["tag/annotated", $Repo]];
	cprops = GitProperties[ToGitObject["HEAD", $Repo]];
	KeyDropFrom[cprops, "Type"];

	props["TagCommitter"] === sig
	&& props["TagMessage"] === "An annotated tag"
    && Merge[{props, cprops}, Last] === props
]


(* ::Text:: *)
(*Annotated tag on a tree*)


VerificationTest[
	tree = GitProperties[ToGitObject["HEAD", $Repo], "Tree"];

	GitType[GitCreateTag[$Repo, "treetag", tree, "the head tree"]] === "Tag"
	&& GitProperties[ToGitObject["treetag", $Repo], "TagTargetType"] === "Tree"
	&& GitProperties[ToGitObject["treetag", $Repo], "TagTarget"] === GitSHA[tree]
]


(* ::Text:: *)
(*Lightweight tags fail on non-commit objs*)


VerificationTest[
	GitCreateTag[$Repo, "lightweighttreetag", tree] === $Failed,
	True,
	{GitCreateTag::gitoperationfailed}
]


GitClose[$Repo];
DeleteDirectory[$RepoDirectory, DeleteContents->True];


EndTestSection[]
