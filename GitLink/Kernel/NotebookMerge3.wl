(* ::Package:: *)

BeginPackage["NotebookMerge3`"]
NotebookMerge3
Begin["`Private`"]


AppendTo[$ContextPath, "NotebookTools`"]

NotebookMerge3[
	Notebook[aCells_List, aOpts___],
	Notebook[lCells_List, lOpts___],
	Notebook[rCells_List, rOpts___]
]:=
Catch[Module[{ancestorOpts,leftOpts,rightOpts,
		ancestorCells,leftCells,rightCells,
		leftPatch,rightPatch,patchedCells,patchedOpts},
	ancestorOpts = Sort@purgeOpts[{aOpts}];
	leftOpts = Sort[{lOpts}];
	rightOpts = Sort@purgeOpts[{rOpts}];
	ancestorCells = FlattenCellGroups[aCells];
	leftCells = FlattenCellGroups[lCells];
	rightCells = FlattenCellGroups[rCells];
	leftPatch = SequenceAlignmentPatch[ancestorCells, leftCells];
	rightPatch = SequenceAlignmentPatch[ancestorCells, rightCells];
	Outer[throwIfConflict, leftPatch, rightPatch];
	leftPatch = SequenceAlignmentPatch[ancestorOpts, leftOpts];
	rightPatch = SequenceAlignmentPatch[ancestorOpts, rightOpts];
	Outer[throwIfConflict, leftPatch, rightPatch];
	patchedCells = ApplyPatch[ancestorCells, MultiAlignmentPatch[ancestorCells, leftCells, rightCells]];
	patchedOpts = ApplyPatch[ancestorOpts, MultiAlignmentPatch[ancestorOpts, leftOpts, rightOpts]];
	If[!MatchQ[patchedCells,{___Cell}] || !MatchQ[patchedOpts, OptionsPattern[]], Throw[$Failed, "NotebookMerge3Conflict"]];
	ExportString[Notebook[{patchedCells}, patchedOpts], "NB"]
], "NotebookMerge3Conflict"]


purgeOpts[opts_List] :=
	DeleteCases[opts,
		_[WindowMargins|WindowSize|FrontEndVersion,_], Infinity]


throwIfConflict[leftPatch_ItemPatch, rightPatch_ItemPatch] :=
Which[
	True,
		True
]


End[]
EndPackage[]
