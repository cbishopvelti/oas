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
import { get } from 'lodash';
import { useEffect, useState } from 'react';
import EditIcon from '@mui/icons-material/Edit';
import { Link, useParams,useOutletContext } from "react-router-dom";
import { TransactionTags } from './TransactionTags';
import moment from 'moment'
import DeleteIcon from '@mui/icons-material/Delete';

const onChange = ({formData, setFormData, key}) => (event) => {
    
  setFormData({
    ...formData,
    [key]: !event.target.value ? undefined : event.target.value
  })
}

export const Transactions = () => {
  const [filterData, setFilterData] = useState({
    from: moment().subtract(1, 'year').format("YYYY-MM-DD"),
    to: moment().format("YYYY-MM-DD"),
    transaction_tags: []
  })
  const { setTitle } = useOutletContext();
  let { data: transactions, loading, refetch } = useQuery(gql`query ($from: String, $to: String, $transaction_tags: [TransactionTagArg]) {
    transactions (from: $from, to: $to, transaction_tags: $transaction_tags) {
      id,
      when,
      what,
      who,
      amount,
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
    variables: filterData
  });
  useEffect(() => {
    setTitle("Transactions");
    refetch()
  }, [])
  transactions = get(transactions, "transactions", [])


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

    console.log("003", transaction_id);
    await delete_mutation({
      variables: {
        transaction_id
      }
    })
    refetch();
  }

  return <div>
    <Box sx={{display: 'flex', gap: 2, m: 2}}>
      <FormControl sx={{ minWidth: 256}}>
        <TextField
          required
          id="from"
          label="From"
          type="date"
          value={get(filterData, "from")}
          onChange={onChange({formData: filterData, setFormData: setFilterData, key: "from"})}
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
          value={get(filterData, "to")}
          onChange={onChange({formData: filterData, setFormData: setFilterData, key: "to"})}
          InputLabelProps={{
            shrink: true,
          }}
        />
      </FormControl>
      <FormControl sx={{minWidth: 256}}>
        <TransactionTags formData={filterData} setFormData={setFilterData} filterMode={true} />
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
              <TableRow key={transaction.id}>
                <TableCell>{transaction.id}</TableCell>
                <TableCell>{transaction.when}</TableCell>
                <TableCell>{transaction.what}</TableCell>
                <TableCell>{transaction.who}</TableCell>
                <TableCell>{transaction.transaction_tags.map(({name}) => name).join(', ')}</TableCell>
                <TableCell>{transaction.amount}</TableCell>
                <TableCell>
                  <IconButton component={Link} to={`/transaction/${transaction.id}`}>
                    <EditIcon />
                  </IconButton>
                  {(get(transaction, 'tokens', []).length == 0 && !get(transaction, 'membership', null)) &&
                    <IconButton onClick={deleteClick({transaction_id: transaction.id})}>
                      <DeleteIcon sx={{color: 'red'}} />
                    </IconButton>
                  }
                </TableCell>
              </TableRow>
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
