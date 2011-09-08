// Copyright 2011 Ooyala, Inc. All Rights Reserved.

#include "termite.h"

#include <log4cxx/net/syslogappender.h>
#include <log4cxx/consoleappender.h>
#include <log4cxx/patternlayout.h>
#include <log4cxx/propertyconfigurator.h>
#include <log4cxx/rollingfileappender.h>
#include <syslog.h>

using log4cxx::BasicConfigurator;
using log4cxx::ConsoleAppender;
using log4cxx::LevelPtr;
using log4cxx::PatternLayout;
using log4cxx::RollingFileAppender;
using log4cxx::net::SyslogAppender;

// TODO(yuval): Make this thread-safe in a better way than a mutex on every call.

namespace termite {

map<string, Termite*> Termite::termites_;
boost::mutex Termite::static_mutex_;

Termite::Termite(string name, const char* file_path, bool enable_syslog, bool enable_console) {
  logger_ = Logger::getLogger(name);
  ConfigureLogger(file_path, enable_syslog, enable_console);
  Properties properties_;
  boost::mutex instance_mutex_;
  is_cache_current_ = true;

  // TODO(yuval): Read manifest file and include json properties.
}

void Termite::SetProperty(string key, string value) {
  boost::mutex::scoped_lock mylock(instance_mutex_);
  is_cache_current_ = false;
  properties_[key.c_str()] = value;
}

void Termite::ClearProperty(string key) {
  boost::mutex::scoped_lock mylock(instance_mutex_);
  is_cache_current_ = false;
  properties_.erase(key.c_str());
}

void Termite::ResetProperties() {
  boost::mutex::scoped_lock mylock(instance_mutex_);
  is_cache_current_ = false;
  properties_.clear();
}

Termite* Termite::GetTermite(string name) {
  return Termite::GetTermite(name, NULL, true, true);
}

Termite* Termite::GetTermite(string name, const char* file_path, bool enable_syslog,
                             bool enable_console) {
  boost::mutex::scoped_lock mylock(static_mutex_);

  Termite* termite = termites_[name.c_str()];
  if (termite == NULL) {
    termite = new Termite(name, file_path, enable_syslog, enable_console);
    termites_[name.c_str()] = termite;
  }
  return termite;
}

void Termite::ForceLog(LevelPtr level, string message) {
  boost::mutex::scoped_lock mylock(instance_mutex_);
  if (!is_cache_current_) {
    RebuildPropertyCache();
  }

  logger_->forcedLog(level, message + cached_prop_str_);
}

void Termite::RebuildPropertyCache() {
  string str(" {");
  bool first = true;
  for (Properties::iterator p = properties_.begin(); p != properties_.end(); ++p) {
    if (first) {
        first = false;
    } else {
        str += ",";
    }
    str += "\"" + p->first + "\":\"" + p->second + "\"";
  }
  str += "}";
  cached_prop_str_ = str;
  is_cache_current_ = true;
}

void Termite::ConfigureLogger(const char* file_path, bool enable_syslog, bool enable_console) {
  if (file_path != NULL) {
    PatternLayout* layout = new PatternLayout("%d %-5p %c [%t]: %m%n");
    RollingFileAppender* appender = new RollingFileAppender(layout, file_path, true);
    appender->setOption("MaxFileSize", "100");
    appender->setOption("MaxBackupIndex", "20");
    logger_->addAppender(appender);
  }
  if (enable_syslog) {
    PatternLayout* layout = new PatternLayout("%-5p %c [%t]: %m%n");
    SyslogAppender* appender = new SyslogAppender(layout, "127.0.0.1", LOG_LOCAL6);
    logger_->addAppender(appender);
  }
  if (enable_console) {
    PatternLayout* layout = new PatternLayout("%-5p %c [%t]: %m%n");
    ConsoleAppender* appender = new ConsoleAppender(layout, "System.err");
    logger_->addAppender(appender);
  }
}

bool Termite::IsTraceEnabled() { return logger_->isTraceEnabled(); }
bool Termite::IsDebugEnabled() { return logger_->isDebugEnabled(); }
bool Termite::IsInfoEnabled() { return logger_->isInfoEnabled(); }
bool Termite::IsWarnEnabled() { return logger_->isWarnEnabled(); }
bool Termite::IsErrorEnabled() { return logger_->isErrorEnabled(); }
bool Termite::IsFatalEnabled() { return logger_->isFatalEnabled(); }

}  // namespace termite
