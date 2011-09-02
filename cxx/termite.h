// #define TERMITE_LEVEL 4
#ifndef __TERMITE_H__
#define __TERMITE_H__

#include <string>
#ifdef __GNUC__
#include <ext/hash_map>
using namespace __gnu_cxx;
#else
#include <hash_map>
#endif

#include <log4cxx/logger.h>
#include <log4cxx/basicconfigurator.h>

#include <boost/thread/mutex.hpp>
using namespace std;

#define TERMITE_TRACE(logger, message) {\
if (logger->IsTraceEnabled()) {\
   logger->ForceLog(::log4cxx::Level::getTrace(), message); }}

#define TERMITE_DEBUG(logger, message) {\
if (logger->IsDebugEnabled()) {\
   logger->ForceLog(::log4cxx::Level::getDebug(), message); }}

#define TERMITE_INFO(logger, message) {\
if (logger->IsInfoEnabled()) {\
   logger->ForceLog(::log4cxx::Level::getInfo(), message); }}

#define TERMITE_WARN(logger, message) {\
if (logger->IsWarnEnabled()) {\
   logger->ForceLog(::log4cxx::Level::getWarn(), message); }}

#define TERMITE_ERROR(logger, message) {\
if (logger->IsErrorEnabled()) {\
   logger->ForceLog(::log4cxx::Level::getError(), message); }}

#define TERMITE_FATAL(logger, message) {\
if (logger->IsFatalEnabled()) {\
   logger->ForceLog(::log4cxx::Level::getFatal(), message); }}

namespace termite {
  class Termite {
   public:
    void SetProperty(string key, string value);
    void ClearProperty(string key);
    void ResetProperties();

    // Get a Termite which logs only to syslog
    static Termite* GetTermite(string name);

    static Termite* GetTermite(string name, const char *filePath, bool enableSyslog);

    void ForceLog(log4cxx::LevelPtr level, string message);

    bool IsTraceEnabled();
    bool IsDebugEnabled();
    bool IsInfoEnabled();
    bool IsWarnEnabled();
    bool IsErrorEnabled();
    bool IsFatalEnabled();

   private:
    Termite(string name, const char *filePath, bool enableSyslog);
    void RebuildPropertyCache();
    void configureLogger(const char *filePath, bool enableSyslog);

    log4cxx::Logger* logger_;
    typedef map<string, string> Properties;
    Properties properties_;
    string cachedPropStr_;
    bool isCacheCurrent_;
    boost::mutex inst_mutex_;

    static map<string, Termite*> termites_;
    static boost::mutex static_mutex_;
  };
}

#endif