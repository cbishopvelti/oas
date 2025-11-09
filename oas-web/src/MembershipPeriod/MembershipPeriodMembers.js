import { gql, useQuery, useMutation } from "@apollo/client"
import { MembersDisplay } from "../Member/MembersDisplay"
import {
  IconButton, Dialog, DialogTitle, FormControl,
  Autocomplete, TextField, Button
 } from "@mui/material";
import { differenceBy, differenceWith, get, reduce } from 'lodash';
import { useParams, useOutletContext, Link } from "react-router-dom";
import { useEffect, useState } from "react";
import DeleteIcon from '@mui/icons-material/Delete';
import PaidIcon from '@mui/icons-material/Paid';
import CardMembershipIcon from '@mui/icons-material/CardMembership';


export const DeleteMembership = ({membership_period_id, membership_period_name, refetch}) => {
  const [mutation] = useMutation(gql`
    mutation ($member_id: Int!, $membership_period_id: Int!) {
      delete_membership(member_id: $member_id, membership_period_id: $membership_period_id) {
        success
      }
    }
  `);

  if (!membership_period_id) {
    return <></>
  }

  return ({member_id, data}) => {
    return <>
      {data.transaction && <IconButton title={`Go to ${membership_period_name}'s transaction`} component={Link} to={`/transaction/${data.transaction.id}`}>
        <PaidIcon />
      </IconButton>}
      <IconButton title={`Delete ${data.member.name}'s membership`} onClick={async () => {
        await mutation({
          variables: {
            membership_period_id,
            member_id
          }
        })
        refetch()
      }}>
        <DeleteIcon sx={{color: 'red'}} />
      </IconButton>

    </>
  }
}

const AddMembership = ({membership_period_id, members: existing_members, changeNo, setChangeNo}) => {
  const [open, setOpen] = useState(false);
  const [member, setMember] = useState({});

  let { data, refetch: refetchMembers } = useQuery(gql`query {
    members {
      id,
      name
    }
  }`);
  let members = get(data, 'members', []);
  members = differenceBy(members, existing_members, ({id}) => { return id })

  let [mutate] = useMutation(gql`
    mutation($member_id: Int!, $membership_period_id: Int!) {
      add_membership(member_id: $member_id, membership_period_id: $membership_period_id) {
        success
      }
    }
  `)
  const addMemberClick = async () => {
    await mutate({
      variables: {
        member_id: member.member_id,
        membership_period_id
      }
    })
    setChangeNo(changeNo + 1)
    setOpen(false)
  }

  return <>
      <IconButton title={`Add member`} onClick={() => setOpen(true)}>
        <CardMembershipIcon />
      </IconButton>
      <Dialog open={open} onClose={() => {setOpen(false)}}>
        <DialogTitle>Select member to add</DialogTitle>
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
        <FormControl sx={{m: 2}}>
          <Button onClick={addMemberClick}>Add to membership period</Button>
        </FormControl>
      </Dialog>
    </>
}


export const MembershipPeriodMembers = () => {
  const { setTitle } = useOutletContext();
  const [changeNo, setChangeNo] = useState(0);

  let { id } = useParams();
  id = parseInt(id);



  const {data, refetch} = useQuery(gql`
    query ($id: Int!) {
      membership_period(id: $id) {
        name
        memberships {
          id,
          transaction {
            id
          }
          member {
            id,
            name,
            email,
            token_count,
            credit_amount,
            inserted_at,
            member_status
          }
        }
      }
    }
  `, {
    variables: {
      id
    }
  })
  useEffect(() => {
    refetch();
  }, [changeNo])

  const members = get(data, "membership_period.memberships", []).map(({member}) => member);

  useEffect(() => {
    const memberCount = members?.length || 0;
    const counts = reduce(members, ({tokenCount, debtCount}, {token_count}) => {
      if (token_count > 0) {
        return {
          tokenCount: tokenCount + token_count,
          debtCount
        }
      } else if (token_count < 0) {
        return {
          tokenCount,
          debtCount: debtCount + token_count
        }
      }
      return {
        tokenCount,
        debtCount
      }
    }, {
      tokenCount: 0,
      debtCount: 0
    })

    setTitle(`Membership Period: ${get(data, 'membership_period.name', id)}'s Members: ${memberCount}, tokens: ${counts.tokenCount}, ${counts.debtCount}`);
  }, [get(data, 'membership_period.name'), members])

  const memberships = get(data, 'membership_period.memberships', [])

  return <>
    <AddMembership members={members} membership_period_id={id} changeNo={changeNo} setChangeNo={setChangeNo} />
    <MembersDisplay data={memberships} dataKey={`member`} ExtraActions={DeleteMembership({membership_period_id: id, membership_period_name: get(data, 'membership_period.name', id), refetch})}/>
  </>
}
