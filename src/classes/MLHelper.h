#ifndef MLHelper_h_
#define MLHelper_h_ 1

#include <deque>
#include <string>
#include <cstring>

class GitLinkRepository;

class MLHelper
{
public:
	MLHelper(MLINK lnk);
	~MLHelper();

	void beginFunction(const char* head);
	void endFunction();

	void beginList() { beginFunction("List"); };
	void endList() { endFunction(); };

	void putString(const char* value);
	void putSymbol(const char* value);
	void putOid(const git_oid& value);
	void putRepo(const GitLinkRepository& repo);

	void putRule(const char* key);
	void putRule(const char* key, int value); // boolean
	void putRule(const char* key, double value);
	void putRule(const char* key, const git_time& value);
	void putRule(const char* key, const char* value);
	void putRule(const char* key, const git_oid& value);
	void putRule(const char* key, git_repository_state_t value);
	void putRule(const char* key, git_status_list* list, git_status_t status);

private:
	MLINK lnk_;
	std::deque<MLINK> tmpLinks_;
	std::deque<int> argCounts_;
	std::deque<bool> unfinishedRule_;

	inline void incrementArgumentCount_() { if (unfinishedRule_.front()) unfinishedRule_.front() = false; else argCounts_.front()++; };
};

class MLString
{
public:
	MLString(MLINK lnk) : lnk_(lnk)
	{
		int unused;
		MLGetUTF8String(lnk, &str_, &len_, &unused);
	};
	virtual ~MLString()
	{
		MLReleaseUTF8String(lnk_, str_, len_);
	};

	const char* str() const {return (const char*) str_; };
	operator const char*() const { return (const char*)str_; };

private:
	const unsigned char* str_;
	int len_;
	MLINK lnk_;
};

class MLBoolean : MLString
{
public:
	MLBoolean(MLINK lnk) : MLString(lnk) { };
	virtual ~MLBoolean() { };

	operator bool() const { return (strcmp(str(), "True") == 0);}
};

class MLAutoMark
{
public:
	MLAutoMark(MLINK lnk, bool rewindOnDestroy) :
		rewindOnDestroy_(rewindOnDestroy), lnk_(lnk), mark_(MLCreateMark(lnk))
	{ };

	~MLAutoMark()
	{
		if (rewindOnDestroy_)
			rewind();
		MLDestroyMark(lnk_, mark_);
		MLClearError(lnk_);
	}

	void rewind() { MLSeekToMark(lnk_, mark_, 0); };

private:
	bool rewindOnDestroy_;
	MLINK lnk_;
	MLMARK mark_;
};

class MLExpr
{
public:
	MLExpr(MLINK lnk);
	MLExpr(const MLExpr& expr);
	~MLExpr() { MLClose(loopbackLink_); };

	void putToLink(MLINK lnk) const;
	bool testSymbol(const char* sym) const;
	bool testHead(const char* sym) const;
	int getInt() const;
	MLExpr part(int i) const;

private:
	mutable MLINK loopbackLink_;

};

extern void MLHandleError(WolframLibraryData libData, const char* functionName,
							const char* messageName, const char* param = NULL);

extern std::string MLGetCPPString(MLINK lnk);

#if SIXTYFOURBIT
#define MLGetMint MLGetInteger64
#else
#define MLGetMint MLGetInteger
#endif

#endif // MLHelper_h_
