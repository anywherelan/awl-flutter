String getServerAddress() {
  const value = String.fromEnvironment("SERVER_ADDR");
  return value;
}
