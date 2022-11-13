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
  Box
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

  let { data: members, loading, refetch } = useQuery(gql`query ($show_all: Boolean) {
    members (show_all: $show_all) {
      id,
      name,
      email,
      token_count,
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
      show_all: filterData.show_all
    }
  });
  members = get(members, "members", []) || []
  useEffect(() => {
    setTitle("Members");
    refetch()
  }, [filterData])

  // console.log('000', members)

  return <div>
    <Box>
      <FormControl sx={{m:2}}>
        <FormControlLabel
            control={
              <Switch 
                checked={get(filterData, 'show_all', false) || false}
                onChange={(event) => setFilterData({...filterData, show_all: event.target.checked})}/>
            }
            label="Show all" />
      </FormControl>
    </Box>
    <MembersDisplay data={members} ExtraActions={DeleteMember({refetch})} />
  </div>
}
