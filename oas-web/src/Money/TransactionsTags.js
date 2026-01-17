import { gql, useMutation, useQuery } from "@apollo/client"
import { Dialog, DialogActions, Button, DialogTitle, DialogContent, FormControl, Box } from "@mui/material"
import { TransactionTags } from "./TransactionTags"
import { useEffect, useState } from "react"

export const TransactionsTags = ({
  selectedTags,
  setSelectedTags,
  refetch,
  transactionsTagsOpen,
  setTransactionsTagsOpen
}) => {
  const [formData, setFormData] = useState({})

  const { data, refetch: lcd_refetch } = useQuery(gql`query($transaction_ids: [Int!]!) {
    transactions_tags(transaction_ids: $transaction_ids) {
      id,
      name
    }
  }`, {
    variables: {
      transaction_ids: Array.from(selectedTags)
    },
    skip: !transactionsTagsOpen
  })

  useEffect(() => {
    setFormData({
      transaction_tags: data?.transactions_tags,
      saveCount: `transactions-tags-${formData.saveCount || 0}`
    })
  }, [data])

  const [mutate, { error }] = useMutation(gql`mutation($transaction_ids: [Int!]!, $transaction_tags: [TransactionTagArg]) {
    transactions_tags(transaction_ids: $transaction_ids, transaction_tags: $transaction_tags) {
      id
    }
  }`)

  const handleTagsClose = (toSave, { outside } = {}) => async () => {
    if (!toSave) {

    } else {
      setFormData((prevFormData) => ({
        ...prevFormData,
        saveCount: (prevFormData.saveCount || 0) + 1
      }))
      await mutate({
        variables: {
          transaction_tags: formData.transaction_tags,
          transaction_ids: Array.from(selectedTags)
        }
      })
      lcd_refetch()
      refetch()
    }
    if (!outside) {
      setSelectedTags(new Set())
    }
    setTransactionsTagsOpen(false) // DEBUG ONLY, uncomment
  }

  return <Dialog
    open={transactionsTagsOpen}
    onClose={() => setTransactionsTagsOpen(false, {outside: true})}
    aria-labelledby="alert-dialog-title"
    aria-describedby="alert-dialog-description"
  >
    <DialogTitle id="alert-dialog-title">
      {`Edit Tags`}
    </DialogTitle>

    <DialogContent sx={{  minWidth: 400 }}>
      <Box sx={{pt: 2}}>
        <TransactionTags
          formData={formData}
          setFormData={setFormData}
        />
      </Box>
    </DialogContent>

    <DialogActions>
      <Button color="error" onClick={handleTagsClose(false)}>Cancel</Button>
      <Button
        disabled={new Set(formData.transactionsTags).isSubsetOf(new Set(data?.transactions_tags)) &&
          new Set(data?.transactions_tags).isSubsetOf(new Set(formData.transaction_tags))
        }
        onClick={handleTagsClose(true)}>
        Save
      </Button>
    </DialogActions>
  </Dialog>
}
