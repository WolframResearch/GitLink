(* ::Package:: *)

BeginPackage["NotebookMerge3`"];

NotebookMerge3::usage = "NotebookMerge3 is an internal utility.";

Begin["`Private`"];

$ContextPath = Append[DeleteCases[$ContextPath, "NotebookTools`"], "NotebookTools`"];


NotebookMerge3[
	Notebook[aCells_List, aOpts___],
	Notebook[lCells_List, lOpts___],
	Notebook[rCells_List, rOpts___]
]:=
Catch[Module[{
		ancestorOpts,leftOpts,rightOpts,
		ancestorCells,leftCells,rightCells,
		ancestorGroups,leftGroups,rightGroups,
		patchedCells,patchedOpts,patchedGroups},

	ancestorOpts = Sort@purgeOpts[{aOpts}];
	leftOpts = Sort[{lOpts}];
	rightOpts = Sort@purgeOpts[{rOpts}];

	ancestorCells = purgeBoxes @ FlattenCellGroups[aCells];
	leftCells = purgeBoxes @ FlattenCellGroups[lCells];
	rightCells = purgeBoxes @ FlattenCellGroups[rCells];

	ancestorGroups = cellGroupStates[aCells];
	leftGroups = cellGroupStates[lCells];
	rightGroups = cellGroupStates[rCells];

	patchedCells = ApplyPatch[ancestorCells, MultiAlignmentPatch[ancestorCells, leftCells, rightCells]];
	patchedOpts = ApplyPatch[ancestorOpts, MultiAlignmentPatch[ancestorOpts, leftOpts, rightOpts]];
	patchedGroups = ApplyPatch[ancestorGroups, MultiAlignmentPatch[ancestorGroups, leftGroups, rightGroups]];

	If[!MatchQ[patchedCells, {___Cell}] || !MatchQ[patchedOpts, OptionsPattern[]],
		Throw[$Failed, "NotebookMerge3Conflict"]
	];

	(* Open / close grouping conflicts are easier to resolve *)
	If[!FreeQ[patchedGroups, _NotebookTools`NotebookDiffDump`CONFLICT],
		(*Message[NotebookMerge3::groupingautofix];*)
		patchedGroups = Replace[patchedGroups, {
			NotebookTools`NotebookDiffDump`CONFLICT[reason_, left_List, right_] :> Sequence @@ left,
			NotebookTools`NotebookDiffDump`CONFLICT[reason_, left_, right_] :> Sequence[] }, {1}]
	];

	(* return the string for the merged notebook *)
	If[StringQ[#], #, $Failed]& @ UsingFrontEnd[MathLink`CallFrontEnd[
		FrontEnd`NotebookToString[Notebook[patchedCells, Sequence @@ patchedOpts], patchedGroups]]]

], "NotebookMerge3Conflict"]


purgeOpts[opts_List] :=
	(* level spec catches notebook-level and stylesheet-notebook-level options *)
	DeleteCases[opts, (Rule|RuleDelayed)[WindowMargins | WindowSize | FrontEndVersion, _], Infinity] 


purgeBoxes[cells_List] :=
	Replace[
		(* purge cell and inline cell options that we're not yet prepared to deal with *)
		ReplaceRepeated[cells, Cell[a__, (ExpressionUUID) -> _, b___] :> Cell[a, b]], 
		(* only purge ImageSizeCache from non-StyleData cells *)
		cell: Cell[Except[_StyleData], ___] :> DeleteCases[cell, (Rule|RuleDelayed)[ImageSizeCache, _], Infinity],
		{1}
	]


cellGroupStates[list_List] := cellGroupStates /@ list;
cellGroupStates[Cell[CellGroupData[list_List, state_]]] := Sequence[state, Sequence @@ cellGroupStates /@ list]
cellGroupStates[other_] := Sequence[]

(*CellGroupStates[Notebook[cells_List, ___]] := cellGroupStates[cells]*)


End[];
EndPackage[];
