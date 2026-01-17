import {
  Table,
  TableContainer,
  TableHead,
  TableRow,
  TableCell,
  TableBody,
  IconButton,
  Box,
  TextField,
  FormControl,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogContentText,
  DialogActions,
  Button,
  Input,
  Checkbox,
} from '@mui/material';
import { StyledTableRow } from '../utils/util'
import { Link, useParams, useOutletContext } from "react-router-dom";
import EditIcon from '@mui/icons-material/Edit';
import { get, reduce, round, padStart, omitBy, omit } from 'lodash';
import DeleteIcon from '@mui/icons-material/Delete';
import { memo } from 'react';


const TransactionRow = memo(({
  transaction,
  deleteClick,
  selectedTag,
  setSelectedTag
}) => {
  return <StyledTableRow className={`${transaction.warnings && 'warnings'}`} key={transaction.id}>
    <TableCell>{transaction.id}</TableCell>
    <TableCell>{transaction.when}</TableCell>
    <TableCell>{transaction.what}</TableCell>
    <TableCell>
      {transaction.who}
    </TableCell>
    <TableCell>
      <Box sx={{
        display: "flex",
        justifyContent: "space-between",
        alignItems: "center",

      }}>
        {transaction.transaction_tags.map(({ name }) => name).join(', ')}
        <Checkbox sx={{}}
          checked={selectedTag || false}
          onChange={(event) => {
            setSelectedTag(event.target.checked)
          }}
        />
      </Box>
    </TableCell>
    <TableCell>{transaction.amount}</TableCell>
    <TableCell>
      <IconButton title={`Edit ${transaction.what}`} component={Link} to={`/transaction/${transaction.id}`}>
        <EditIcon />
      </IconButton>
      {(get(transaction, 'tokens', []).length == 0 && !get(transaction, 'membership', null)) &&
        <IconButton title={`Delete ${transaction.what}`} onClick={deleteClick({transaction_id: transaction.id})}>
          <DeleteIcon sx={{color: 'red'}} />
        </IconButton>
      }
    </TableCell>
  </StyledTableRow>
}, (old, newArgs) => {
  return old.transaction === newArgs.transaction && old.selectedTag === newArgs.selectedTag
})

export const TransactionsRows = memo(({
  transactions,
  deleteClick,
  selectedTags,
  setSelectedTags
}) => {
  return transactions.map((transaction, i) => {
    const setSelectedTag = (checked) => {
      setSelectedTags(prevSelected => {
        if (!checked) {
          prevSelected.delete(transaction.id)
          return new Set(prevSelected)
        } else {
          prevSelected.add(transaction.id)
          return new Set(prevSelected)
        }
      })
    }

    return <TransactionRow
      key={i}
      selectedTag={selectedTags.has(transaction.id)}
      setSelectedTag={setSelectedTag}
      transaction={transaction}
      deleteClick={deleteClick}
    />
  })
}, (old, newArgs) => {
  if (old.transactions === newArgs.transactions && old.selectedTags === newArgs.selectedTags) {
    return true
  } else {
    return false
  }
})
