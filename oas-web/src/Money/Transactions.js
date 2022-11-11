import { gql, useQuery } from '@apollo/client';
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
  FormControl
} from '@mui/material';
import { get } from 'lodash';
import { useEffect, useState } from 'react';
import EditIcon from '@mui/icons-material/Edit';
import { Link, useParams,useOutletContext } from "react-router-dom";
import { TransactionTags } from './TransactionTags';
import moment from 'moment'

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
    }
  }`, {
    variables: filterData
  });
  useEffect(() => {
    setTitle("Transactions");
    refetch()
  }, [])
  transactions = get(transactions, "transactions", [])

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
                </TableCell>
              </TableRow>
            ))
          }
        </TableBody>
      </Table>
    </TableContainer>
  </div>
}
