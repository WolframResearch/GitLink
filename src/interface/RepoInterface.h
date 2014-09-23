/*
 *  gitLink
 *
 *  Created by John Fultz on 6/18/14.
 *  Copyright (c) 2014 Wolfram Research. All rights reserved.
 *
 */

#ifndef RepoInterface_h_
#define RepoInterface_h_ 1

#ifdef __GNUC__
#include <ext/hash_map>

namespace stdext
{
	using namespace __gnu_cxx;
}

#else
#include <hash_map>
#endif



extern stdext::hash_map<mint, git_repository *> ManagedRepoMap;

extern DLLEXPORT void manageRepoInstance(WolframLibraryData libData, mbool mode, mint id);


#endif // RepoInterface_h_
