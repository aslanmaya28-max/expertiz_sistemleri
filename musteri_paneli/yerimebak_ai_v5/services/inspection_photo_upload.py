"""Sınırlı multipart akışını yalnız bellekte toplar; UploadFile/spool kullanmaz."""
from python_multipart import MultipartParser
from python_multipart.multipart import parse_options_header
from yerimebak_ai_v5.services.inspection_photo import MAX_FILE, PhotoError

MAX_BODY = 4 * MAX_FILE + 64 * 1024


async def files_from_request(request):
    media, options = parse_options_header(request.headers.get('content-type', ''))
    boundary = options.get(b'boundary', b'')
    if media != b'multipart/form-data' or not boundary or len(boundary) > 200:
        raise PhotoError('Fotoğrafları çok parçalı dosya yüklemesi olarak gönderin.', 415)
    length = request.headers.get('content-length')
    if length and length.isdigit() and int(length) > MAX_BODY:
        raise PhotoError('Toplam fotoğraf boyutu sınırı aşıldı.', 413)
    files, part, headers = [], bytearray(), {}
    header_name, header_value = bytearray(), bytearray()
    header_size = 0
    ended = False

    def part_begin():
        nonlocal header_size
        if len(files) >= 4:
            raise PhotoError('Bir rapor için en fazla 4 fotoğraf yükleyin.')
        part.clear()
        headers.clear()
        header_size = 0

    def header_field(data, start, end):
        nonlocal header_size
        header_size += end - start
        if header_size > 8192:
            raise PhotoError('Fotoğraf yükleme başlığı çok uzun.')
        header_name.extend(data[start:end])

    def header_data(data, start, end):
        nonlocal header_size
        header_size += end - start
        if header_size > 8192:
            raise PhotoError('Fotoğraf yükleme başlığı çok uzun.')
        header_value.extend(data[start:end])

    def header_end():
        headers[bytes(header_name).lower()] = bytes(header_value)
        header_name.clear()
        header_value.clear()

    def headers_finished():
        disposition, opts = parse_options_header(headers.get(b'content-disposition', b''))
        if disposition != b'form-data' or opts.get(b'name') != b'files' or not opts.get(b'filename'):
            raise PhotoError('Fotoğrafları files alanıyla gönderin.')

    def part_data(data, start, end):
        if len(part) + end - start > MAX_FILE:
            raise PhotoError('Her fotoğraf en fazla 8 MB olmalıdır.', 413)
        part.extend(data[start:end])

    def part_end():
        if not part:
            raise PhotoError('Boş fotoğraf yüklenemez.')
        files.append(bytes(part))
        part.clear()

    def on_end():
        nonlocal ended
        ended = True

    parser = MultipartParser(boundary, {
        'on_part_begin': part_begin, 'on_header_field': header_field,
        'on_header_value': header_data, 'on_header_end': header_end,
        'on_headers_finished': headers_finished, 'on_part_data': part_data,
        'on_part_end': part_end, 'on_end': on_end,
    })
    total = 0
    try:
        async for chunk in request.stream():
            total += len(chunk)
            if total > MAX_BODY:
                raise PhotoError('Toplam fotoğraf boyutu sınırı aşıldı.', 413)
            parser.write(chunk)
        parser.finalize()
    except PhotoError:
        raise
    except Exception:
        raise PhotoError('Fotoğraf yüklemesi tamamlanamadı; tekrar deneyin.') from None
    if not ended or not 1 <= len(files) <= 4:
        raise PhotoError('Tamamlanmış 1–4 fotoğraf yükleyin.')
    return files
