#ifndef __ONED_RESULT_POINT_H__
#define __ONED_RESULT_POINT_H__
/*
 *  OneDResultPoint.h
 *  ZXing
 *
 *  Copyright 2010 ZXing authors All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#include <zxing/ResultPoint.h>
#include <cmath>

namespace zxing {
	namespace oned {
		
		class OneDResultPoint : public ResultPoint {
		private:
			float posX_;
			float posY_;
			
		public:
			OneDResultPoint(float posX, float posY);
			float getX() const;
			float getY() const;
		};
	}
}

#endif
