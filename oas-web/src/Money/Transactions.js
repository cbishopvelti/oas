import { gql, useMutation, useQuery } from '@apollo/client';
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

} from '@mui/material';
import { get, reduce, round } from 'lodash';
import { useEffect, useState } from 'react';
import { useState as persistentUseState } from '../utils/useState';
import EditIcon from '@mui/icons-material/Edit';
import { Link, useParams,useOutletContext } from "react-router-dom";
import { TransactionTags } from './TransactionTags';
import moment from 'moment'
import DeleteIcon from '@mui/icons-material/Delete';
import { unparse } from 'papaparse';
import DownloadIcon from '@mui/icons-material/Download';
import { StyledTableRow } from '../utils/util'

const onChange = ({formData, setFormData, key, required}) => (event) => {
  setFormData({
    ...formData,
    [key]: !event.target.value ? undefined : event.target.value
  })
}

export const Transactions = () => {
  const [filterData, setFilterData] = persistentUseState({
    from: moment().subtract(1, 'year').format("YYYY-MM-DD"),
    to: moment().format("YYYY-MM-DD"),
    transaction_tags: []
  }, {id: 'Transactions'})
  let { member_id } = useParams();
  if (member_id) {
    member_id = parseInt(member_id)
  }

  const {data: memberData} = useQuery(gql`query ($member_id: Int!) {
    member(member_id: $member_id) {
      name
    }
  }`, {
    variables: {
      member_id
    },
    skip: !member_id
  })

  const { setTitle } = useOutletContext();
  let { data: transactions, loading, refetch } = useQuery(gql`query ($from: String, $to: String, $transaction_tags: [TransactionTagArg], $member_id: Int) {
    transactions (from: $from, to: $to, transaction_tags: $transaction_tags, member_id: $member_id) {
      id,
      when,
      what,
      who,
      amount,
      warnings
      transaction_tags {
        name
      }
      membership {
        id
      }
      tokens {
        id
      }
    }
  }`, {
    variables: {
      member_id,
      ...filterData
    },
    skip: !filterData.to || !filterData.from
  });
  useEffect(() => {
    let transactionCount = transactions.length
    const counts = reduce(transactions, ({incoming, outgoing}, {amount}) => {
      if (amount > 0) {
        return {
          incoming: incoming + parseFloat(amount),
          outgoing
        }
      } else if (amount < 0) {
        return {
          incoming,
          outgoing: outgoing + parseFloat(amount)
        }
      }
      return { incoming, outgoing};
    }, {incoming: 0, outgoing: 0});

    if (member_id) {
      setTitle(`Member: ${get(memberData, 'member.name', member_id)}'s Transactions: ${transactionCount} (${round(counts.incoming, 2)}, ${round(counts.outgoing, 2)}, ${round(counts.incoming + counts.outgoing, 2)})`)
    } else {
      setTitle(`Transactions: ${transactionCount} (${round(counts.incoming, 2)}, ${round(counts.outgoing, 2)}, ${round(counts.incoming + counts.outgoing, 2)})`);
    }
  }, [get(memberData, 'member.name'), transactions])
  transactions = get(transactions, "transactions", []) || []

  useEffect(() => {
    refetch()
  }, [member_id]);

  const [delete_mutation] = useMutation(gql`
    mutation ($transaction_id: Int!) {
      delete_transaction (transaction_id: $transaction_id) {
        success
      }
    }
  `)
  const [deleteOpen, setDeleteOpen] = useState(0)
  const deleteClick = ({transaction_id}) => () => {
    setDeleteOpen(transaction_id);
  }
  const handleDeleteClose = (doDelete) => async () => {
    const transaction_id = deleteOpen;
    setDeleteOpen(0)
    if (!doDelete) {
      return;
    }

    await delete_mutation({
      variables: {
        transaction_id
      }
    })
    refetch();
  }

  return <div>
    <Box sx={{display: 'flex', gap: 2, m: 2, alignItems: 'center'}}>
      <FormControl sx={{ minWidth: 256}}>
        <TextField
          required
          id="from"
          label="From"
          type="date"
          value={get(filterData, "from", '')}
          onChange={onChange({formData: filterData, setFormData: setFilterData, key: "from", required: true})}
          InputLabelProps={{
            shrink: true,
          }}
        />
      </FormControl>
      <FormControl sx={{ minWidth: 256}}>
        <TextField
          required
          id="to"
          label="To"
          type="date"
          value={get(filterData, "to", '')}
          onChange={onChange({formData: filterData, setFormData: setFilterData, key: "to", required: true})}
          InputLabelProps={{
            shrink: true,
          }}
        />
      </FormControl>
      <FormControl sx={{minWidth: 256}}>
        <TransactionTags formData={filterData} setFormData={setFilterData} filterMode={true} />
      </FormControl>
      <FormControl>
        <IconButton onClick={() => {
          const csvTransactions = transactions.map(({transaction_tags, ...rest}) => {
            return {
              ...rest,
              tags: transaction_tags.map(({name}) => name).join(', ')
            }
          });

          const csv = unparse({data: csvTransactions, fields: ['id', "when", 'what', 'who', 'tags', 'when', 'amount'], header: true})
          let j = document.createElement("a")
          j.download = "transactions.csv"
          j.href = URL.createObjectURL(new Blob([csv]), {type: "text/csv"})
          j.click()
        }}>
          <DownloadIcon />
        </IconButton>
      </FormControl>
    </Box>
    <TableContainer>
      <Table>
        <TableHead>
          <TableRow>
            <TableCell>Id</TableCell>
            <TableCell>When</TableCell>
            <TableCell>What</TableCell>
            <TableCell>Who</TableCell>
            <TableCell>Tags</TableCell>
            <TableCell>Amount</TableCell>
            <TableCell>Actions</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {
            transactions.map((transaction) => (
              <StyledTableRow className={`${transaction.warnings && 'warnings'}`} key={transaction.id}>
                <TableCell>{transaction.id}</TableCell>
                <TableCell>{transaction.when}</TableCell>
                <TableCell>{transaction.what}</TableCell>
                <TableCell>{transaction.who}</TableCell>
                <TableCell>{transaction.transaction_tags.map(({name}) => name).join(', ')}</TableCell>
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
            ))
          }
        </TableBody>
      </Table>
    </TableContainer>
    <Dialog
        open={deleteOpen != 0}
        onClose={handleDeleteClose(false)}
        aria-labelledby="alert-dialog-title"
        aria-describedby="alert-dialog-description"
      >
        <DialogTitle id="alert-dialog-title">
          {`Delete Transaction`}
        </DialogTitle>
        <DialogContent>
          <DialogContentText id="alert-dialog-description">
            Are you sure you want to delete transaction {deleteOpen}
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button color="error" onClick={handleDeleteClose(false)}>No</Button>
          <Button onClick={handleDeleteClose(true)}>
            Yes
          </Button>
        </DialogActions>
      </Dialog>
  </div>
}
