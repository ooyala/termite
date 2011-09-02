#include "termite.h"
#include <syslog.h>
#include <log4cxx/propertyconfigurator.h>
#include <log4cxx/patternlayout.h>
#include <log4cxx/net/syslogappender.h>
#include <log4cxx/rollingfileappender.h>

using namespace log4cxx;
using namespace log4cxx::helpers;
using namespace log4cxx::net;
using namespace termite;

// TODO(yuval): make this thread-safe in a better way than a mutex on every call
namespace termite {
  map<string, Termite*> Termite::termites_;
  boost::mutex Termite::static_mutex_;

  Termite::Termite(string name, const char *filePath, bool enableSyslog) {
    logger_ = Logger::getLogger(name);
    configureLogger(filePath, enableSyslog);
    Properties properties_;
    boost::mutex inst_mutex_;
    isCacheCurrent_ = true;

    // TODO(yuval): read manifest file and include json properties
  }

  void Termite::SetProperty(string key, string value) {
    boost::mutex::scoped_lock mylock(inst_mutex_);
    isCacheCurrent_ = false;
    properties_[key.c_str()] = value;
  }

  void Termite::ClearProperty(string key) {
    boost::mutex::scoped_lock mylock(inst_mutex_);
    isCacheCurrent_ = false;
    properties_.erase(key.c_str());
  }

  void Termite::ResetProperties() {
    boost::mutex::scoped_lock mylock(inst_mutex_);
    isCacheCurrent_ = false;
    properties_.clear();
  }

  Termite* Termite::GetTermite(string name) {
      return Termite::GetTermite(name, NULL, true);
  }

  Termite* Termite::GetTermite(string name, const char *filePath, bool enableSyslog) {
    boost::mutex::scoped_lock mylock(static_mutex_);

    Termite* termite = termites_[name.c_str()];
    if (termite == NULL) {
      termite = new Termite(name, filePath, enableSyslog);
      termites_[name.c_str()] = termite;
    }
    return termite;
  }

  void Termite::ForceLog(LevelPtr level, string message) {
    boost::mutex::scoped_lock mylock(inst_mutex_);
    if (!isCacheCurrent_) {
      RebuildPropertyCache();
    }

    logger_->forcedLog(level, message + cachedPropStr_);
  }

  void Termite::RebuildPropertyCache() {
    string str(" {");
    bool first=true;
    for (Properties::iterator p = properties_.begin(); p != properties_.end(); ++p) {
        if (first) {
            first = false;
        }
        else {
            str += ",";
        }
        str += "\"" + p->first + "\":\"" + p->second + "\"";
    }
    str += "}";
    cachedPropStr_ = str;
    isCacheCurrent_ = true;
  }


  // Configure log4cxx
  void Termite::configureLogger(const char *filePath, bool enableSyslog) {
    PatternLayout *layout = new PatternLayout("%c [%t]: %m%n");
    if (filePath != NULL) {
        RollingFileAppender *appender = new RollingFileAppender(layout, filePath, true);
        appender->setOption("MaxFileSize","100");
        appender->setOption("MaxBackupIndex","20");
        BasicConfigurator::configure(appender);
    }
    if (enableSyslog) {
        SyslogAppender *appender = new SyslogAppender(layout, "127.0.0.1", LOG_LOCAL6);
        BasicConfigurator::configure(appender);
    }
  }

  bool Termite::IsTraceEnabled() { return logger_->isTraceEnabled(); }
  bool Termite::IsDebugEnabled() { return logger_->isDebugEnabled(); }
  bool Termite::IsInfoEnabled() { return logger_->isInfoEnabled(); }
  bool Termite::IsWarnEnabled() { return logger_->isWarnEnabled(); }
  bool Termite::IsErrorEnabled() { return logger_->isErrorEnabled(); }
  bool Termite::IsFatalEnabled() { return logger_->isFatalEnabled(); }

}