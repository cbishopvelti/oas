import { gql, useQuery, useMutation } from '@apollo/client';
import {
  Table,
  TableContainer,
  TableHead,
  TableRow,
  TableCell,
  TableBody,
  IconButton,
  FormControlLabel,
  Switch,
  FormControl,
  Box,
  Autocomplete,
  TextField
} from '@mui/material';
import { get } from 'lodash';
import { Link, useParams, useOutletContext } from 'react-router-dom';
import { useEffect, useState } from 'react';
import { MembersDisplay } from './MembersDisplay';
import DeleteIcon from '@mui/icons-material/Delete';
import PaidIcon from '@mui/icons-material/Paid';

export const DeleteMember = ({ refetch }) => {
  const [mutation] = useMutation(gql`
    mutation ($member_id: Int!) {
      delete_member(member_id: $member_id) {
        success
      }
    }
  `);
  return ({member}) => {
    let out = []

    // if (get(member, "transactions", []).length > 0) {
      out = [...out, <IconButton key={"1"} title={`Go to ${get(member, 'name')}'s transactions`} component={Link} to={`/member/${member.id}/transactions`}>
        <PaidIcon />
      </IconButton>]
    // }

    if (get(member, "tokens", []).length == 0 && get(member, "membership_periods", []).length == 0 && get(member, "transactions", []).length == 0) {
      out = [...out, <IconButton key={"2"} title={`Delete ${get(member, 'name')}`} onClick={async () => {
        await mutation({
          variables: {
            member_id: member.id,
          }
        })
        refetch()
      }}>
        <DeleteIcon sx={{color: 'red'}} />
      </IconButton>];
    }

    return out;
  }
}

export const Members = () => {
  const { setTitle } = useOutletContext();
  const [filterData, setFilterData] = useState({})

  let { data: members, loading, refetch } = useQuery(gql`query ($show_all: Boolean, $member_id: Int) {
    members (show_all: $show_all, member_id: $member_id) {
      id,
      name,
      email,
      token_count,
      inserted_at,
      member_status,
      tokens {
        id
      },
      membership_periods {
        id
      },
      transactions {
        id
      }
    }
  }`, {
    variables: {
      show_all: filterData.show_all,
      member_id: filterData.member?.member_id
    }
  });
  members = get(members, "members", []) || []
  useEffect(() => {
    setTitle("Members");
    refetch()
  }, [filterData])

  return <div>
    <Box sx={{display: "flex", flexWrap: 'wrap', alignItems: 'center'}}>
      <FormControl sx={{m:2}}>
        <FormControlLabel
            control={
              <Switch 
                checked={get(filterData, 'show_all', false) || false}
                onChange={(event) => setFilterData({...filterData, show_all: event.target.checked})}/>
            }
            label="Show all" />
      </FormControl>
      <FormControl sx={{m:2, minWidth: 256}}>
        <Autocomplete
          id="member"
          value={filterData.member?.member_name || ''}
          options={members.map(({name, id}) => ({label: name, member_id: id }))}
          renderInput={(params) => <TextField {...params} label="Who" />}
          freeSolo
          onChange={(event, newValue, a, b, c, d) => {
            if (!newValue) {
              return setFilterData({
                ...filterData,
                member: null
              })
            }
            setFilterData({
              ...filterData,
              member: {
                member_id: newValue.member_id,
                member_name: newValue.label
              }
            })
          }}
          />
      </FormControl>
    </Box>
    <MembersDisplay data={members} ExtraActions={DeleteMember({refetch})} />
  </div>
}
