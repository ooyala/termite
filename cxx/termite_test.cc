// Copyright 2011 Ooyala, Inc. All Rights Reserved.

#include <gtest/gtest.h>
#include <fstream>
#include <string>

#include "termite.h"

using std::ifstream;
using termite::Termite;

string ReadAndNormalizeLog(const char *filename) {
  string result("");
  string line;
  ifstream logfile(filename);
  if (logfile.is_open()) {
    while (logfile.good()) {
      getline(logfile, line);
      line = line.replace(0, 24, "");  // Strip the time.
      int openBracket = line.find('[');
      if (openBracket >= 0) {
        int closeBracket = line.find(']');
        line = line.replace(openBracket, closeBracket-openBracket, "[");  // Strip thread.
        result += line + "\n";
      }
    }
    logfile.close();
  }
  return result;
}

TEST(TermiteTest, Base) {
  remove("termite_test_base.log");
  Termite* logger = Termite::GetTermite("BaseTest", "termite_test_base.log", false, false);
  logger->SetProperty("mykey", "my value");
  logger->SetProperty("mykey2", "my value2");

  TERMITE_DEBUG(logger, "Debug");
  logger->ClearProperty("mykey");
  TERMITE_INFO(logger, "Info");
  logger->ResetProperties();
  TERMITE_WARN(logger, "Warn");
  TERMITE_ERROR(logger, "Error");
  TERMITE_FATAL(logger, "Fatal");

  EXPECT_EQ("DEBUG BaseTest []: Debug {\"mykey\":\"my value\",\"mykey2\":\"my value2\"}\n\
INFO  BaseTest []: Info {\"mykey2\":\"my value2\"}\n\
WARN  BaseTest []: Warn {}\n\
ERROR BaseTest []: Error {}\n\
FATAL BaseTest []: Fatal {}\n",
            ReadAndNormalizeLog("termite_test_base.log"));
}

TEST(TermiteTest, Stream) {
  remove("termite_test_stream.log");
  Termite* logger = Termite::GetTermite("StreamTest", "termite_test_stream.log", false, false);
  const char* test_chars = "Test chars";
  int test_int = 42;
  string test_string = "Test string";

  TERMITE_DEBUG(logger, "Stream test: " << test_chars << test_int << test_string << ".");
  TERMITE_INFO(logger, "Stream test: " << test_chars << test_int << test_string << ".");
  TERMITE_WARN(logger, "Stream test: " << test_chars << test_int << test_string << ".");
  TERMITE_ERROR(logger, "Stream test: " << test_chars << test_int << test_string << ".");
  TERMITE_FATAL(logger, "Stream test: " << test_chars << test_int << test_string << ".");

  EXPECT_EQ("DEBUG StreamTest []: Stream test: Test chars42Test string.\n\
INFO  StreamTest []: Stream test: Test chars42Test string.\n\
WARN  StreamTest []: Stream test: Test chars42Test string.\n\
ERROR StreamTest []: Stream test: Test chars42Test string.\n\
FATAL StreamTest []: Stream test: Test chars42Test string.\n",
            ReadAndNormalizeLog("termite_test_stream.log"));
}

int main(int argc, char **argv) {
  testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
