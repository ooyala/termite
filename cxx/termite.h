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
   std::ostringstream stream;\
   stream << message;\
   logger->ForceLog(::log4cxx::Level::getTrace(), stream.str()); }}

#define TERMITE_DEBUG(logger, message) {\
if (logger->IsDebugEnabled()) {\
   std::ostringstream stream;\
   stream << message;\
   logger->ForceLog(::log4cxx::Level::getDebug(), stream.str()); }}

#define TERMITE_INFO(logger, message) {\
if (logger->IsInfoEnabled()) {\
   std::ostringstream stream;\
   stream << message;\
   logger->ForceLog(::log4cxx::Level::getInfo(), stream.str()); }}

#define TERMITE_WARN(logger, message) {\
if (logger->IsWarnEnabled()) {\
   std::ostringstream stream;\
   stream << message;\
   logger->ForceLog(::log4cxx::Level::getWarn(), stream.str()); }}

#define TERMITE_ERROR(logger, message) {\
if (logger->IsErrorEnabled()) {\
   std::ostringstream stream;\
   stream << message;\
   logger->ForceLog(::log4cxx::Level::getError(), stream.str()); }}

#define TERMITE_FATAL(logger, message) {\
if (logger->IsFatalEnabled()) {\
   std::ostringstream stream;\
   stream << message;\
   logger->ForceLog(::log4cxx::Level::getFatal(), stream.str()); }}

namespace termite {
  class Termite {
   public:
    void SetProperty(string key, string value);
    void ClearProperty(string key);
    void ResetProperties();

    // Get a Termite which logs only to syslog
    static Termite* GetTermite(string name);

    static Termite* GetTermite(string name, const char *filePath, bool enableSyslog, bool enableConsole);

    void ForceLog(log4cxx::LevelPtr level, string message);

    bool IsTraceEnabled();
    bool IsDebugEnabled();
    bool IsInfoEnabled();
    bool IsWarnEnabled();
    bool IsErrorEnabled();
    bool IsFatalEnabled();

   private:
    Termite(string name, const char *filePath, bool enableSyslog, bool enableConsole);
    void RebuildPropertyCache();
    void ConfigureLogger(const char *filePath, bool enableSyslog, bool enableConsole);

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

