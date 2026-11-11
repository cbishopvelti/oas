import { gql, useMutation } from '@apollo/client';
import {
  Alert,
  Box,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  IconButton,
  Link,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow
} from '@mui/material';
import UploadIcon from '@mui/icons-material/Upload';
import { parse, unparse } from 'papaparse';
import { useRef, useState } from 'react';

const IMPORT_MEMBERS = gql`
  mutation ($rows: [MemberImportRowArg!]!, $dry_run: Boolean!) {
    import_members(rows: $rows, dry_run: $dry_run) {
      saved
      create_count
      skip_count
      error_count
      opening_credit_total
      rows { row name email opening_credit outcome reason }
    }
  }
`;

const OUTCOME_LABEL = {
  CREATE: 'Create',
  SKIP: 'Skip',
  ERROR: 'Error'
};

const OUTCOME_COLOR = {
  CREATE: 'success.main',
  SKIP: 'text.secondary',
  ERROR: 'error.main'
};

const downloadTemplate = (event) => {
  event.preventDefault();
  const csv = unparse({ fields: ['name', 'email', 'opening_credit'], data: [] });
  const link = document.createElement('a');
  link.download = 'members-template.csv';
  link.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }));
  link.click();
};

const hasCredit = (summary) => parseFloat(summary?.opening_credit_total || '0') > 0;

const parseFile = (file) => new Promise((resolve, reject) => {
  parse(file, {
    header: true,
    skipEmptyLines: 'greedy',
    transformHeader: (header) => header.trim().toLowerCase(),
    complete: ({ data, meta }) => {
      const fields = meta.fields || [];
      if (!fields.includes('name') || !fields.includes('email')) {
        return reject(new Error('The CSV needs a header row with "name" and "email" columns.'));
      }
      resolve(data.map((row) => ({
        name: row.name || '',
        email: row.email || '',
        opening_credit: row.opening_credit || ''
      })));
    },
    error: reject
  });
});

export const ImportMembers = ({ onImported }) => {
  const [open, setOpen] = useState(false);
  const [rows, setRows] = useState(null);
  const [preview, setPreview] = useState(null);
  const [result, setResult] = useState(null);
  const [error, setError] = useState(null);
  const fileInput = useRef(null);
  const [importMembers, { loading }] = useMutation(IMPORT_MEMBERS);

  const reset = () => {
    setRows(null);
    setPreview(null);
    setResult(null);
    setError(null);
    if (fileInput.current) fileInput.current.value = '';
  };

  const close = () => {
    setOpen(false);
    reset();
  };

  const onFile = async (event) => {
    const file = event.target.files?.[0];
    if (!file) return;
    setPreview(null);
    setResult(null);
    setError(null);
    try {
      const parsed = await parseFile(file);
      if (parsed.length === 0) {
        throw new Error('The CSV has no rows.');
      }
      const { data } = await importMembers({ variables: { rows: parsed, dry_run: true } });
      setRows(parsed);
      setPreview(data.import_members);
    } catch (e) {
      setRows(null);
      setError(e.message);
    }
  };

  const onImport = async () => {
    setError(null);
    try {
      const { data } = await importMembers({ variables: { rows, dry_run: false } });
      if (data.import_members.saved) {
        setResult(data.import_members);
        onImported && onImported();
      } else {
        // Something changed since the preview (e.g. someone registered); show why.
        setPreview(data.import_members);
        setError('Nothing was imported. Check the rows marked Error.');
      }
    } catch (e) {
      setError(e.message);
    }
  };

  const shown = result || preview;
  const canImport = preview && !result && preview.error_count === 0 && preview.create_count > 0;

  return <>
    <IconButton title="Import members" onClick={() => setOpen(true)}>
      <UploadIcon />
    </IconButton>
    <Dialog open={open} onClose={close} maxWidth="md" fullWidth>
      <DialogTitle>Import members</DialogTitle>
      <DialogContent>
        <Box sx={{ mb: 2 }}>
          Choose a CSV with <code>name</code> and <code>email</code> columns, and optionally
          an <code>opening_credit</code> column.{' '}
          <Link href="#" onClick={downloadTemplate}>Download template CSV</Link>.
          {' '}Members whose email already exists are skipped and left unchanged. No emails are sent.
        </Box>
        <Box sx={{ mb: 2 }}>
          Leave <code>opening_credit</code> blank or 0 for no credit. Each opening balance above 0 is
          recorded as an incoming transaction ("Opening balance") on the import date, so it appears
          in that day's income totals.
        </Box>
        {!result && <Button variant="outlined" component="label" disabled={loading}>
          Choose CSV
          <input ref={fileInput} hidden type="file" accept=".csv,text/csv" onChange={onFile} />
        </Button>}
        {error && <Alert severity="error" sx={{ mt: 2 }}>{error}</Alert>}
        {result && <Alert severity="success" sx={{ mt: 2 }}>
          Imported {result.create_count} member{result.create_count === 1 ? '' : 's'}, skipped {result.skip_count}.
          {hasCredit(result) && ` Opening credit added: ${result.opening_credit_total}.`}
        </Alert>}
        {preview && !result && <Alert severity={preview.error_count > 0 ? 'warning' : 'info'} sx={{ mt: 2 }}>
          {preview.create_count} to create, {preview.skip_count} to skip, {preview.error_count} with errors.
          {hasCredit(preview) && ` Opening credit to add: ${preview.opening_credit_total}.`}
          {preview.error_count > 0 && ' Fix the rows with errors and choose the file again; nothing is imported while any row has an error.'}
        </Alert>}
        {shown && <TableContainer sx={{ mt: 2, maxHeight: 400 }}>
          <Table size="small" stickyHeader>
            <TableHead>
              <TableRow>
                <TableCell>Row</TableCell>
                <TableCell>Name</TableCell>
                <TableCell>Email</TableCell>
                <TableCell>Opening credit</TableCell>
                <TableCell>Outcome</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {shown.rows.map((row) => <TableRow key={row.row}>
                <TableCell>{row.row}</TableCell>
                <TableCell>{row.name}</TableCell>
                <TableCell>{row.email}</TableCell>
                <TableCell>{row.opening_credit}</TableCell>
                <TableCell sx={{ color: OUTCOME_COLOR[row.outcome] }}>
                  {OUTCOME_LABEL[row.outcome]}{row.reason ? `: ${row.reason}` : ''}
                </TableCell>
              </TableRow>)}
            </TableBody>
          </Table>
        </TableContainer>}
      </DialogContent>
      <DialogActions>
        <Button onClick={close}>{result ? 'Done' : 'Cancel'}</Button>
        {!result && <Button variant="contained" disabled={!canImport || loading} onClick={onImport}>
          Import {preview?.create_count || 0} member{preview?.create_count === 1 ? '' : 's'}
        </Button>}
      </DialogActions>
    </Dialog>
  </>;
};
