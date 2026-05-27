const admin = require('firebase-admin');
const axios = require('axios');
const serviceAccount = require('./serviceAccountKey.json');

// Firebase 초기화
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// 공공 API 정보
const API_KEY = "2ef64ea1d04581cf581f79eaec90862314df41f3c836075f4eeee7cbe096b7fa";
const BASE_URL = `http://211.237.50.150:7080/openapi/${API_KEY}/json`;

const ENDPOINTS = {
  BASIC: 'Grid_20150827000000000226_1', // 기본 정보
  INGREDIENTS: 'Grid_20150827000000000227_1', // 재료 정보
  STEPS: 'Grid_20150827000000000228_1' // 조리 순서
};

/**
 * 특정 엔드포인트의 모든 데이터를 페이지네이션하며 가져오는 함수
 */
async function fetchAll(key) {
  let allRows = [];
  let start = 1;
  const batchSize = 1000;
  let hasMore = true;

  console.log(`[Fetching] ${key} 데이터 로딩 시작...`);

  while (hasMore) {
    const end = start + batchSize - 1;
    const url = `${BASE_URL}/${key}/${start}/${end}`;
    
    try {
      const response = await axios.get(url);
      const data = response.data[key];
      
      if (data && data.row && data.row.length > 0) {
        allRows = allRows.concat(data.row);
        console.log(`  - ${key}: ${start} ~ ${end} (누적: ${allRows.length}개)`);
        
        if (data.row.length < batchSize) {
          hasMore = false;
        } else {
          start += batchSize;
        }
      } else {
        hasMore = false;
      }
    } catch (error) {
      console.error(`  - ${key} 에러 발생 (${start}~${end}): ${error.message}`);
      hasMore = false;
    }
  }
  return allRows;
}

/**
 * 조리 시간 문자열을 숫자로 변환 (예: "30분" -> 30)
 */
function parseMinutes(timeStr) {
  if (!timeStr) return 999;
  let minutes = 0;
  const hourMatch = timeStr.match(/(\d+)\s*시간/);
  const minMatch = timeStr.match(/(\d+)\s*분/);
  if (hourMatch) minutes += parseInt(hourMatch[1]) * 60;
  if (minMatch) minutes += parseInt(minMatch[1]);
  return minutes > 0 ? minutes : 999;
}

async function main() {
  try {
    console.log("🚀 데이터 동기화 프로세스 시작...");

    // 1. 모든 데이터 병렬로 가져오기
    const [basicRows, ingreRows, stepRows] = await Promise.all([
      fetchAll(ENDPOINTS.BASIC),
      fetchAll(ENDPOINTS.INGREDIENTS),
      fetchAll(ENDPOINTS.STEPS)
    ]);

    console.log(`\n✅ API 데이터 수집 완료!`);
    console.log(`- 기본 정보: ${basicRows.length}건`);
    console.log(`- 재료 정보: ${ingreRows.length}건`);
    console.log(`- 조리 순서: ${stepRows.length}건\n`);

    let batch = db.batch(); // let 으로 재할당 가능하게
    let count = 0;
    let batchCount = 0;

    // 2. 데이터 병합 및 Firestore 업로드
    for (const basic of basicRows) {
      const id = basic.RECIPE_ID.toString().trim();
      
      // ─── 0Kcal 필터링 (데이터 누락 레시피 제외) ───
      const calRaw = (basic.CALORIE || "").toString().trim().toLowerCase();
      if (calRaw === "0kcal" || calRaw === "0 kcal" || calRaw === "0") {
        // console.log(`[Skip] 0Kcal 레시피 제외: ${basic.RECIPE_NM_KO} (${id})`);
        continue;
      }

      const recipeRef = db.collection('recipes').doc(id);

      // ─── 기존 데이터 확인 (보존용) ───
      const doc = await recipeRef.get();
      const exists = doc.exists;
      const existingData = exists ? doc.data() : {};

      // 재료 매칭
      const matchedIng = ingreRows
        .filter(i => i.RECIPE_ID.toString().trim() === id)
        .map(i => `${i.IRDNT_NM} (${i.IRDNT_CPCTY || ''})`);

      // 조리 순서 매칭 및 정렬
      const matchedSteps = stepRows
        .filter(s => s.RECIPE_ID.toString().trim() === id)
        .sort((a, b) => parseInt(a.COOKING_NO) - parseInt(b.COOKING_NO))
        .map(s => s.COOKING_DC.toString());

      // ─── 필드 결정 로직 (최고 수준의 보존 정책) ───
      const recipeData = {
        name: basic.RECIPE_NM_KO,
        summary: basic.SUMRY,
        calorie: basic.CALORIE || "정보 없음",
        qnt: basic.QNT || "정보 없음",
        time: basic.COOKING_TIME || "정보 없음",
        timeMinutes: parseMinutes(basic.COOKING_TIME),
        level: basic.LEVEL_NM || "정보 없음",
        nation: basic.NATION_NM || "한식",
        type: basic.TY_NM || "기타",
        ingredients: matchedIng,
        steps: matchedSteps,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      };

      // 1. 이미지 보존: 기존에 이미지가 '절대' 없는 경우만 API 값을 추가함
      if (!exists || !existingData.imgUrl || existingData.imgUrl === "") {
        recipeData.imgUrl = basic.IMG_URL || "";
      }
      // 이미 이미지가 있다면 recipeData에 imgUrl 필드 자체를 넣지 않음. 
      // merge: true 이므로 기존 imgUrl은 그대로 유지됨.

      // 2. 통계 필드가 없는 경우(신규 또는 기존 누락) 초기화
      if (!exists || existingData.viewCount === undefined) {
        recipeData.viewCount = 0;
        recipeData.todayViewCount = 0;
        recipeData.yesterdayViewCount = 0;
        recipeData.todayDate = new Date().toISOString().split('T')[0];
      }
      // 기존 문서라면 recipeData에 위 필드들이 없으므로 기존 값이 100% 보존됨.

      batch.set(recipeRef, recipeData, { merge: true });

      count++;
      batchCount++;

      // Firestore 배치는 한 번에 500개까지만 가능
      if (batchCount === 500) {
        await batch.commit();
        console.log(`[Upload] Firestore에 ${count}개 저장 완료...`);
        batch = db.batch();
        batchCount = 0;
      }
    }

    // 남은 데이터 저장
    if (batchCount > 0) {
      await batch.commit();
    }

    console.log(`\n🎉 총 ${count}개의 레시피 동기화가 성공적으로 완료되었습니다!`);
    process.exit(0);

  } catch (error) {
    console.error("\n❌ 동기화 중 치명적인 에러 발생:");
    console.error(error);
    process.exit(1);
  }
}

main();
