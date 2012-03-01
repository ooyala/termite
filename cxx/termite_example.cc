// Copyright 2011 Ooyala, Inc. All Rights Reserved.
//
// Example usage of Termite logging utility.

#include "termite.h"

using termite::Termite;

int main(int argc, char **argv) {
  string app("MyApp");
  Termite* logger = Termite::GetTermite(app, "termite_example.log", true, true);
  logger->SetProperty("mykey", "my value");
  logger->SetProperty("mykey2", "my value2");

  TERMITE_INFO(logger, "Entering application.");
  logger->ClearProperty("mykey");
  TERMITE_ERROR(logger, "Oh No!");
  logger->ResetProperties();
  TERMITE_INFO(logger, "Exiting application.");

  return EXIT_SUCCESS;
}
