import { gql, useMutation, useQuery, useSubscription } from '@apollo/client';
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
import { get, reduce, round, padStart, includes, pickBy } from 'lodash';
import { useEffect, useState, useMemo } from 'react';
import { useState as persistentUseState } from '../utils/useState';
import EditIcon from '@mui/icons-material/Edit';
import { Link, useParams,useOutletContext } from "react-router-dom";
import { TransactionTags } from './TransactionTags';
import moment from 'moment'
import DeleteIcon from '@mui/icons-material/Delete';
import { unparse } from 'papaparse';
import DownloadIcon from '@mui/icons-material/Download';
import { StyledTableRow } from '../utils/util'
import { TransactionsRows } from './TransactionsRows';
import { TransactionsTags } from './TransactionsTags';

const onChange = ({formData, setFormData, key, required}) => (event) => {
  setFormData({
    ...formData,
    [key]: !event.target.value ? undefined : event.target.value
  })
}

const rerun_time = (transactionData) => {
  if (!get(transactionData, "gocardless_trans_status.next_run")) {
    return ''
  }

  return `, Next import run: ${moment(get(transactionData, "gocardless_trans_status.next_run"), "HH:mm:ss.SSSSSS").format("HHmm")}`
}

const GocardlessImportCountdownComponent = ({
  transactionData
}) => {
  let when = moment(get(transactionData, "gocardless_trans_status.next_run"), "HH:mm:ss.SSSSSS")

  const [countdown, setCountdown] = useState("");

  useEffect(() => {
    let interval = null

    if (when.isBefore(moment())) {
      when.add(1, 'day');
    }

    const doTimer = () => {
      const now = moment()

      setCountdown(
        `${padStart(when.diff(now, 'hours'), 2, '0')}:${padStart(when.diff(now, 'minutes') % 60, 2, '0')}:${padStart(when.diff(now, 'seconds') % 60, 2, '0')}`
      );

      if (when.diff(now, 'seconds') < 0) {
        interval && clearInterval(interval)
        setCountdown("Loading...")
      }
    }

    doTimer()
    interval = setInterval(doTimer, 1000);

    return () => {
      clearInterval(interval);
    }
  }, []);

  return <div>
    Next import: {countdown}
  </div>
}
export const GocardlessImportCountdown = (transactionData) => {
  return <GocardlessImportCountdownComponent transactionData={transactionData} />
}

export const Transactions = () => {
  const [filterData, setFilterData] = persistentUseState({
    wat: "what",
    from: moment().subtract(1, 'year').format("YYYY-MM-DD"),
    to: moment().format("YYYY-MM-DD"),
    transaction_tags: []
  }, { id: 'Transactions' })
  const [whoFilter, setWhoFilter] = useState("")
  const [selectedTags, setSelectedTags] = useState(new Set())
  const [ transactionsTagsOpen, setTransactionsTagsOpen] = useState(false)

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

  const { setTitle, setComponents } = useOutletContext();
  let { data: transactionData, loading, refetch } = useQuery(gql`query ($from: String, $to: String, $transaction_tags: [TransactionTagArg], $member_id: Int) {
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
    gocardless_trans_status {
      next_run
    }
  }`, {
    variables: {
      member_id,
      ...filterData
    },
    skip: !filterData.to || !filterData.from
  });
  const transactions = get(transactionData, "transactions", []) || []
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
      setTitle(`Member: ${get(memberData, 'member.name', member_id)}'s Transactions: ${transactionCount} (${round(counts.incoming, 2)}, ${round(counts.outgoing, 2)}`)
    } else {
      setTitle(`Transactions: ${transactionCount} (${round(counts.incoming, 2)}, ${round(counts.outgoing, 2)}, ${round(counts.incoming + counts.outgoing, 2)})`);
    }
    if (get(transactionData, "gocardless_trans_status.next_run")) {
      setComponents([GocardlessImportCountdown(transactionData)])
    }
  }, [get(memberData, 'member.name'), transactions, transactionData])

  useSubscription(gql`
    subscription {
      gocardless_trans_status {
        success
      }
    }
  `, {
    onData({ }) {
      refetch()
    }
  })

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

  const filteredTransactions = useMemo(() => {
    return transactions.filter((transaction) => {
      return includes(transaction.who, whoFilter)
    })
  }, [transactions, whoFilter])

  useEffect(() => {
    const transIds = new Set(filteredTransactions.map((tran) => tran.id))
    setSelectedTags((prevTags) => prevTags.intersection(transIds))
  }, [filteredTransactions])

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
            <TableCell>

              <Box sx={{display: "flex", justifyContent: "space-between", alignItems: "center"}}>
                Who
                <Input
                  placeholder={"Filter"}
                  type="text"
                  variant='standard'
                  size='small'
                  value={whoFilter}
                  onChange={(event) => setWhoFilter(event.target.value)}
                  sx={{
                    ml: 2, fontSize: 12
                    }} />

              </Box>
            </TableCell>
            <TableCell>
              <Box sx={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "center",
              }}>
                Tags
                <Box>
                  {selectedTags.size > 0 && <Button
                    onClick={() => setTransactionsTagsOpen(true)}
                    >Edit</Button>}
                  <Checkbox
                    sx={{}}
                    checked={new Set(filteredTransactions.map(tran => tran.id)).isSubsetOf(selectedTags)}
                    onChange={(event) => {
                      setSelectedTags(prevTags => {
                        if (!event.target.checked) {
                          return new Set()
                        } else {
                          return new Set(filteredTransactions.map((tran) => {
                            return tran.id
                          }))
                        }
                      })
                    }}
                    />
                </Box>
              </Box>
            </TableCell>
            <TableCell>Amount</TableCell>
            <TableCell>Actions</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          <TransactionsRows
            deleteClick={deleteClick}
            transactions={filteredTransactions}
            setSelectedTags={setSelectedTags}
            selectedTags={selectedTags}
            />
        </TableBody>
      </Table>
    </TableContainer>
    <Dialog
        open={deleteOpen !== 0}
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
    <TransactionsTags
      selectedTags={selectedTags}
      setSelectedTags={setSelectedTags}
      refetch={refetch}
      transactionsTagsOpen={transactionsTagsOpen}
      setTransactionsTagsOpen={setTransactionsTagsOpen}
    />
  </div>
}
