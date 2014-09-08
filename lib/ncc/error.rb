#!ruby
# /* Copyright 2013 Proofpoint, Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# */


class NCC

end

class NCC::Error < StandardError

end

class NCC::Error::NotFound < NCC::Error

end

class NCC::Error::Cloud < NCC::Error

end

class NCC::Error::Internal < NCC::Error

end

class NCC::Error::Client < NCC::Error

end
