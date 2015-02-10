/*
 *  gitLink
 *
 *  Created by John Fultz on 6/18/14.
 *  Copyright (c) 2014 Wolfram Research. All rights reserved.
 *
 */

#ifndef RepoInterface_h_
#define RepoInterface_h_ 1

#include <unordered_map>

extern std::unordered_map<mint, git_repository *> ManagedRepoMap;

extern DLLEXPORT void manageRepoInstance(WolframLibraryData libData, mbool mode, mint id);


#endif // RepoInterface_h_
