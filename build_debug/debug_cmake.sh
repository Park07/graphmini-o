cmake \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_CXX_FLAGS="-fsanitize=address -fsanitize=undefined -g -O1" \
  -DCMAKE_C_FLAGS="-fsanitize=address -fsanitize=undefined -g -O1" \
  ..
