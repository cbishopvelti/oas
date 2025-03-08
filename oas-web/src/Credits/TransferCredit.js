import { useState, useEffect } from 'react';
import {
  Dialog, IconButton, DialogTitle, FormControl,
  Autocomplete, TextField, Button
} from "@mui/material"
import TransferWithinAStationIcon from '@mui/icons-material/TransferWithinAStation';
import { useQuery, gql, useMutation } from '@apollo/client'
import { filter, get } from 'lodash';


export const TransferCredit = ({
  member_id,
  changeNo,
  setChangeNo
}) => {

  const [open, setOpen] = useState(false);
  const [member, setMember] = useState({});
  const [amount, setAmount] = useState("");

  let { data, refetch: refetchMembers } = useQuery(gql`query {
    members {
      id,
      name
    }
  }`);
  let members = get(data, 'members', []);
  members = filter(members, ({id}) => id !== member_id);
  useEffect(() => {
    refetchMembers()
  }, [member_id])

  const [mutate, {error}] = useMutation(gql`
    mutation ($from_member_id: Int!, $to_member_id: Int!, $amount: String!) {
      transfer_credit (from_member_id: $from_member_id, to_member_id: $to_member_id, amount: $amount) {
        success
      }
    }
  `);

  const transferClick = async () => {
    await mutate({
      variables: {
        from_member_id: member_id,
        to_member_id: member.member_id,
        amount: amount
      }
    })
    setChangeNo(changeNo + 1);
    setOpen(false); //DEBUG ONLY, uncomment
  }

  return <>
    <IconButton title={`Transfer token`} onClick={() => setOpen(true)}>
      <TransferWithinAStationIcon />
    </IconButton>
    <Dialog open={open} onClose={() => {setOpen(false)}}>
      <DialogTitle>Select member to transfer to</DialogTitle>
      <FormControl sx={{m: 2, minWidth: 256}}>
        <Autocomplete
          id="member"
          required
          value={member.member_name || null}
          isOptionEqualToValue={(a, b) => {
            return a.label === b
          }}
          options={members.map(({name, id}) => ({label: name, member_id: id }))}
          renderInput={(params) => <TextField {...params} required label="Who" />}
          onChange={(event, newValue, a, b, c, d) => {
            setMember({
              member_id: newValue.member_id,
              member_name: newValue.label
            })
          }}
          />
      </FormControl>
      <FormControl sx={{m: 2, minWidth: 256}}>
        <TextField
          label="Credits amount"
          value={ amount }
          type="text"
          inputMode="numeric"
          pattern="[0-9\.]*"
          required
          onChange={(event) => {
            let amount = event.target.value;
            setAmount(amount)
          }}
        />
      </FormControl>
      <FormControl sx={{m: 2}}>
        <Button onClick={transferClick}>Transfer</Button>
      </FormControl>
    </Dialog>
  </>
}
