// Copyright 2011 Ooyala, Inc. All Rights Reserved.
//
// Provides centralized logging functionality for C++ server applications.

#ifndef SHARED_LIB_LOGGING_CXX_TERMITE_H_
#define SHARED_LIB_LOGGING_CXX_TERMITE_H_

#include <boost/thread/mutex.hpp>
#include <log4cxx/logger.h>
#include <log4cxx/basicconfigurator.h>
#include <map>
#include <string>

using log4cxx::Logger;
using std::string;
using std::map;

#define TERMITE_TRACE(logger, message) \
  if (logger->IsTraceEnabled()) { \
    std::ostringstream stream; \
    stream << message; \
    logger->ForceLog(log4cxx::Level::getTrace(), stream.str()); \
  }

#define TERMITE_DEBUG(logger, message) \
  if (logger->IsDebugEnabled()) { \
    std::ostringstream stream; \
    stream << message; \
    logger->ForceLog(log4cxx::Level::getDebug(), stream.str()); \
  }

#define TERMITE_INFO(logger, message) \
  if (logger->IsInfoEnabled()) {\
    std::ostringstream stream; \
    stream << message; \
    logger->ForceLog(log4cxx::Level::getInfo(), stream.str()); \
  }

#define TERMITE_WARN(logger, message) \
  if (logger->IsWarnEnabled()) { \
    std::ostringstream stream; \
    stream << message; \
    logger->ForceLog(log4cxx::Level::getWarn(), stream.str()); \
  }

#define TERMITE_ERROR(logger, message) \
  if (logger->IsErrorEnabled()) { \
    std::ostringstream stream; \
    stream << message; \
    logger->ForceLog(log4cxx::Level::getError(), stream.str()); \
  }

#define TERMITE_FATAL(logger, message) \
  if (logger->IsFatalEnabled()) { \
    std::ostringstream stream; \
    stream << message; \
    logger->ForceLog(log4cxx::Level::getFatal(), stream.str()); \
  }

namespace termite {

class Termite {
 public:
  // Allows the user to set key-value pairs which are passed as JSON with each log message.
  void SetProperty(string key, string value, bool key_is_string = true, bool value_is_string = true);

  // Removes the key-value pair with the given key from the JSON list.
  void ClearProperty(string key, bool key_is_string = true);

  // Removes all the key-value pairs from the JSON list.
  void ResetProperties();

  // Returns a Termite which logs to syslog and the console, but not to file.
  static Termite* GetTermite(string name);

  // Returns a Termite which logs to the specified output methods.
  static Termite* GetTermite(string name, const char* file_path, bool enable_syslog,
                             bool enable_console);

  // Appends the JSON key-value pair list to the given message and logs it at the given level.
  void ForceLog(log4cxx::LevelPtr level, string message);

  bool IsTraceEnabled();
  bool IsDebugEnabled();
  bool IsInfoEnabled();
  bool IsWarnEnabled();
  bool IsErrorEnabled();
  bool IsFatalEnabled();

 private:
  Termite(string name, const char* file_path, bool enable_syslog, bool enable_console);

  // Creates the JSON key-value pair list and caches it.
  void RebuildPropertyCache();

  // Configures underlying log4cxx logger.
  void ConfigureLogger(const char* file_path, bool enable_syslog, bool enable_console);

  log4cxx::Logger* logger_;
  typedef map<string, string> Properties;
  Properties properties_;
  string cached_prop_str_;
  bool is_cache_current_;
  boost::mutex instance_mutex_;

  static map<string, Termite*> termites_;
  static boost::mutex static_mutex_;
};

}  // namespace termite

#endif  // SHARED_LIB_LOGGING_CXX_TERMITE_H_
