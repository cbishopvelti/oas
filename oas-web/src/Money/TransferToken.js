import { useState, useEffect } from 'react';
import { Dialog, IconButton, DialogTitle, FormControl, Autocomplete, TextField, Button } from "@mui/material"
import TransferWithinAStationIcon from '@mui/icons-material/TransferWithinAStation';
import { useQuery, gql, useMutation } from '@apollo/client'
import { get } from 'lodash';



export const TransferToken = ({token, refetch}) => {
  const [open, setOpen] = useState(false);
  const [member, setMember] = useState({});

  let { data, refetch: refetchMembers } = useQuery(gql`query {
    members {
      id,
      name
    }
  }`);
  const members = get(data, 'members', []);
  useEffect(() => {
    refetchMembers()
  }, [token.id])


  const [mutate] = useMutation(gql`
    mutation ($member_id: Int!, $token_id: Int!) {
      transfer_token (member_id: $member_id, token_id: $token_id) {
        id
      }
    }
  `);
  const transferClick = ({
    member,
    token_id
  }) => async () => {
    await mutate({
      variables: {
        member_id: member.member_id,
        token_id: parseInt(token_id)
      }
    })
    refetch()
    setOpen(false);
  }

  return <>
    <IconButton onClick={() => setOpen(true)}>
      <TransferWithinAStationIcon />
    </IconButton>
    <Dialog open={open} onClose={() => {console.log("hnadle close"); setOpen(false)}}>
      <DialogTitle>Select member to transfer to</DialogTitle>
      <FormControl sx={{m: 2, minWidth: 256}}>
        <Autocomplete
          id="member"
          required
          value={member.member_name || ''}
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
      <FormControl sx={{m: 2}}>
        <Button onClick={transferClick({member, token_id: token.id})}>Transfer</Button>
      </FormControl>
    </Dialog>
  </>
}