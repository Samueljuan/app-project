const SHEET_ID = '1ISLFFJKkfUkDQ2NoAl772k9jjAr_wVo-tBfa9-4AcUA';
const SHEET_NAME = 'Sheet1';

function doPost(e) {
  try {
    const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_NAME);
    if (!sheet) {
      throw new Error(`Sheet "${SHEET_NAME}" tidak ditemukan`);
    }

    const payload = getPayload_(e);

    sheet.appendRow([
      new Date(),
      payload.value || '',
      payload.scannedAt || '',
    ]);

    return buildResponse_({ status: 'success', message: 'Data berhasil disimpan' });
  } catch (err) {
    console.error(err);
    return buildResponse_({ status: 'error', message: err.toString() }, 500);
  }
}

function getPayload_(e) {
  if (e && e.parameter && Object.keys(e.parameter).length) {
    return e.parameter;
  }

  if (e && e.postData && e.postData.contents) {
    try {
      return JSON.parse(e.postData.contents);
    } catch (error) {
      console.warn('Gagal parse JSON:', error);
    }
  }
  return {};
}

function buildResponse_(body, statusCode) {
  const output = ContentService.createTextOutput(JSON.stringify(body))
    .setMimeType(ContentService.MimeType.JSON)
    .setHeader('Access-Control-Allow-Origin', '*')
    .setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (statusCode) {
    output.setResponseCode(statusCode);
  }
  return output;
}
