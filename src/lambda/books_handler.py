# 書籍管理APIハンドラ（日本語コメント）
# - POST /books: 書籍を登録（UUID発行）
# - GET /books/{bookId}: 1件取得
# - GET /books: 一覧取得（最大100件）
import json
import os
import uuid
import logging
import boto3
from botocore.exceptions import BotoCoreError, ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ddb = boto3.resource('dynamodb')
TABLE = ddb.Table(os.environ['TABLE_NAME'])

ALLOWED_STATUS = {'未読', '読了'}


def _response(status, body):
    return {
        'statusCode': status,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps(body, ensure_ascii=False)
    }


def _handle_post_books(event):
    body = json.loads(event.get('body') or '{}')
    title = (body.get('title') or '').strip()
    author = (body.get('author') or '').strip()
    status = body.get('status') or '未読'
    published = body.get('publishedDate')

    if not title:
        return _response(400, {'code': 'VALIDATION_ERROR', 'message': 'title is required'})
    if not author:
        return _response(400, {'code': 'VALIDATION_ERROR', 'message': 'author is required'})
    if status not in ALLOWED_STATUS:
        return _response(400, {'code': 'VALIDATION_ERROR', 'message': 'status must be 未読 or 読了'})

    book_id = str(uuid.uuid4())
    item = {'BookId': book_id, 'title': title, 'author': author, 'status': status}
    if published:
        item['publishedDate'] = published
    TABLE.put_item(Item=item)
    logger.info({'action': 'put_item', 'bookId': book_id})
    return _response(201, {'bookId': book_id})


def _handle_get_book(book_id: str):
    res = TABLE.get_item(Key={'BookId': book_id})
    item = res.get('Item')
    if not item:
        return _response(404, {'code': 'NOT_FOUND', 'message': 'book not found'})
    out = {
        'bookId': item['BookId'],
        'title': item['title'],
        'author': item['author'],
        'status': item['status']
    }
    if 'publishedDate' in item:
        out['publishedDate'] = item['publishedDate']
    return _response(200, out)


def _handle_list_books():
    limit = 100
    res = TABLE.scan(Limit=limit)
    items = [{
        'bookId': it['BookId'],
        'title': it['title'],
        'author': it['author'],
        'status': it['status'],
        **({'publishedDate': it['publishedDate']} if 'publishedDate' in it else {})
    } for it in res.get('Items', [])]
    body = {'items': items, 'count': len(items)}
    if 'LastEvaluatedKey' in res:
        body['lastEvaluatedKey'] = res['LastEvaluatedKey'].get('BookId')
    return _response(200, body)


def lambda_handler(event, _context):
    # ルーティング（Lambda Proxy）
    method = event.get('httpMethod')
    path = event.get('path', '')
    logger.info({'event': {'method': method, 'path': path}})

    try:
        if method == 'POST' and path.endswith('/books'):
            return _handle_post_books(event)

        if method == 'GET' and '/books/' in path:
            book_id = path.rsplit('/', 1)[-1]
            return _handle_get_book(book_id)

        if method == 'GET' and path.endswith('/books'):
            return _handle_list_books()

        return _response(404, {'code': 'NOT_FOUND', 'message': 'route not found'})
    except (BotoCoreError, ClientError) as e:
        logger.exception('DynamoDB error')
        return _response(503, {'code': 'DDB_ERROR', 'message': 'temporary unavailable'})
    except Exception as e:  # 予期しないエラー
        logger.exception('Unhandled error')
        return _response(500, {'code': 'INTERNAL_ERROR', 'message': 'unexpected error'})
