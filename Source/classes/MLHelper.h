#ifndef MLHelper_h_
#define MLHelper_h_ 1

#include <deque>

class MLHelper
{
public:
	MLHelper(MLINK lnk) : lnk_(lnk) { };
	~MLHelper();

	void beginFunction(const char* head);
	void endFunction();

	void beginList() { beginFunction("List"); };
	void endList() { endFunction(); };

	void putString(const char* value);
	void putSymbol(const char* value);

	void putRule(const char* key);
	void putRule(const char* key, int value);
	void putRule(const char* key, const char* value);
	void putRule(const char* key, git_repository_state_t value);
	void putRule(const char* key, git_status_list* list, git_status_t status);

private:
	MLINK lnk_;
	std::deque<MLINK> tmpLinks_;
	std::deque<int> argCounts_;
};

#endif // MLHelper_h_
