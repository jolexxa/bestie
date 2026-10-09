import 'package:model_downloader/model_downloader.dart';
import 'package:test/test.dart';

void main() {
  test('describes each HTTP status a person can act on', () {
    expect(
      {
        for (final status in [401, 403, 404, 416, 502])
          status: DownloadHttpStatus(status).message,
      },
      {
        401: contains('authentication'),
        403: contains('denied'),
        404: contains('not found'),
        416: contains('byte range'),
        502: contains('HTTP 502'),
      },
    );
  });

  test('describes every other failure', () {
    expect(
      [
        const DownloadNetworkError('connection reset'),
        const DownloadDiskFull(),
        const DownloadIoError('permission denied'),
        const DownloadTruncated(expectedBytes: 10, receivedBytes: 7),
        const DownloadUnsafePath(relativePath: '../x', directory: '/models'),
        const DownloadWorkerError('isolate died'),
      ].map((failure) => failure.message),
      [
        contains('connection reset'),
        contains('disk space'),
        contains('permission denied'),
        allOf(contains('7'), contains('10')),
        allOf(contains('../x'), contains('/models')),
        contains('isolate died'),
      ],
    );
  });

  test('DownloadFailed shows its reason', () {
    const failed = DownloadFailed(DownloadHttpStatus(404));

    expect(failed.message, failed.reason.message);
  });
}
