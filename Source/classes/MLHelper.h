#ifndef MLHelper_h_
#define MLHelper_h_ 1

#include <deque>

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
	~MLString()
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

#endif // MLHelper_h_
