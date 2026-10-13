import { useState } from 'react'
import { Link as RouterLink, Outlet, useLocation, useNavigate } from 'react-router-dom'
import {
  AppBar, Box, Button, Divider, Drawer, IconButton, List, ListItemButton, ListItemIcon,
  ListItemText, Toolbar, Typography, useMediaQuery,
} from '@mui/material'
import MenuIcon from '@mui/icons-material/Menu'
import PeopleAltOutlinedIcon from '@mui/icons-material/PeopleAltOutlined'
import InsightsOutlinedIcon from '@mui/icons-material/InsightsOutlined'
import { useTheme } from '@mui/material/styles'
import { useSession } from '../auth/useSession'

const drawerWidth = 244
const navigation = [
  { label: 'Employees', path: '/employees', icon: <PeopleAltOutlinedIcon /> },
  { label: 'Insights', path: '/insights', icon: <InsightsOutlinedIcon /> },
]

export function AppLayout() {
  const { user, logout } = useSession()
  const [mobileOpen, setMobileOpen] = useState(false)
  const theme = useTheme()
  const desktop = useMediaQuery(theme.breakpoints.up('md'))
  const location = useLocation()
  const navigate = useNavigate()
  const [logoutError, setLogoutError] = useState('')

  async function handleLogout() {
    setLogoutError('')
    try {
      await logout()
      navigate('/login', { replace: true })
    } catch {
      setLogoutError('Unable to log out. Please try again.')
    }
  }

  const drawer = (
    <Box sx={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <Toolbar>
        <Typography variant="h6" color="primary.dark">Salary Desk</Typography>
      </Toolbar>
      <Divider />
      <List sx={{ px: 1.5, py: 2 }}>
        {navigation.map((item) => (
          <ListItemButton
            component={RouterLink}
            to={item.path}
            key={item.path}
            selected={location.pathname.startsWith(item.path)}
            onClick={() => setMobileOpen(false)}
            sx={{ borderRadius: 2, mb: 0.5 }}
          >
            <ListItemIcon>{item.icon}</ListItemIcon>
            <ListItemText primary={item.label} />
          </ListItemButton>
        ))}
      </List>
      <Box sx={{ mt: 'auto', p: 2 }}>
        {logoutError && <Typography role="alert" color="error" variant="caption">{logoutError}</Typography>}
        <Typography variant="body2" noWrap sx={{ mb: 1 }}>{user?.email}</Typography>
        <Button fullWidth variant="outlined" onClick={handleLogout}>Log out</Button>
      </Box>
    </Box>
  )

  return (
    <Box sx={{ minHeight: '100vh', display: 'flex' }}>
      <AppBar position="fixed" color="inherit" elevation={0} sx={{ borderBottom: 1, borderColor: 'divider', zIndex: (t) => t.zIndex.drawer + 1 }}>
        <Toolbar>
          {!desktop && (
            <IconButton aria-label="Open navigation" edge="start" onClick={() => setMobileOpen(true)} sx={{ mr: 1 }}>
              <MenuIcon />
            </IconButton>
          )}
          <Typography variant="h6" sx={{ flexGrow: 1 }}>Salary Management</Typography>
          <Typography variant="body2" color="text.secondary" sx={{ display: { xs: 'none', sm: 'block' } }}>
            HR workspace
          </Typography>
        </Toolbar>
      </AppBar>
      <Box component="nav" aria-label="Main navigation" sx={{ width: { md: drawerWidth }, flexShrink: { md: 0 } }}>
        <Drawer
          variant={desktop ? 'permanent' : 'temporary'}
          open={desktop || mobileOpen}
          onClose={() => setMobileOpen(false)}
          ModalProps={{ keepMounted: true }}
          sx={{
            '& .MuiDrawer-paper': {
              width: drawerWidth,
              boxSizing: 'border-box',
              borderRight: { md: 1 },
              borderColor: 'divider',
            },
          }}
        >
          {drawer}
        </Drawer>
      </Box>
      <Box component="main" sx={{ flexGrow: 1, minWidth: 0, pt: 10, px: { xs: 2, sm: 3, lg: 4 }, pb: 5 }}>
        <Outlet />
      </Box>
    </Box>
  )
}
