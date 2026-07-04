import { useState } from 'react';
import { getAuditLogs } from '../api/admin';
import { useAsync } from '../lib/useAsync';
import { dateTime } from '../lib/format';
import {
  Badge,
  Card,
  EmptyState,
  ErrorState,
  PageHeader,
  Spinner,
} from '../components/ui';
import { Pagination, TBody, TD, THead, TR, Table } from '../components/Table';

export default function AuditLogs() {
  const [page, setPage] = useState(1);
  const [targetType, setTargetType] = useState('');
  const { data, loading, error } = useAsync(
    () =>
      getAuditLogs({
        page,
        limit: 25,
        targetType: targetType.trim() || undefined,
      }),
    [page, targetType],
  );

  return (
    <>
      <PageHeader
        title="Audit Logs"
        subtitle="Every administrative action, newest first"
        actions={
          <input
            value={targetType}
            onChange={(e) => {
              setTargetType(e.target.value);
              setPage(1);
            }}
            placeholder="Filter by target type"
            className="w-52 rounded-lg border border-slate-300 px-3 py-1.5 text-sm outline-none focus:border-slate-900"
          />
        }
      />

      <Card>
        {loading && <Spinner />}
        {error && <ErrorState message={error} />}
        {data && data.logs.length === 0 && (
          <EmptyState message="No audit entries found." />
        )}
        {data && data.logs.length > 0 && (
          <>
            <Table>
              <THead cols={['Action', 'Target', 'Target ID', 'Details', 'When']} />
              <TBody>
                {data.logs.map((log) => (
                  <TR key={log.id}>
                    <TD>
                      <Badge tone="purple">
                        {log.action.replace(/_/g, ' ')}
                      </Badge>
                    </TD>
                    <TD className="capitalize">
                      {log.targetType.replace(/_/g, ' ')}
                    </TD>
                    <TD>
                      <span className="font-mono text-xs text-slate-500">
                        {log.targetId}
                      </span>
                    </TD>
                    <TD>
                      {log.metadata &&
                      Object.keys(log.metadata).length > 0 ? (
                        <code className="block max-w-xs overflow-x-auto whitespace-nowrap rounded bg-slate-50 px-2 py-1 text-xs text-slate-600">
                          {JSON.stringify(log.metadata)}
                        </code>
                      ) : (
                        <span className="text-slate-300">—</span>
                      )}
                    </TD>
                    <TD>{dateTime(log.createdAt)}</TD>
                  </TR>
                ))}
              </TBody>
            </Table>
            <Pagination
              page={data.pagination.page}
              totalPages={data.pagination.totalPages}
              total={data.pagination.total}
              onChange={setPage}
            />
          </>
        )}
      </Card>
    </>
  );
}
